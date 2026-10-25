import Foundation

// Real facts per app for Resolve All: review history from ASC, and from GitHub what the code is and whether any of it is shared.
// The drafter writes from these only, so a reply never needs a [placeholder] for something Hermes can read for itself.

enum Facts {
    struct Repo: Codable { var name: String; var files: [String: String]; var readme: String; var ids: [String: String] }

    static let gh = "/opt/homebrew/bin/gh"
    static let owner = "nulljosh"
    static var cache: URL { SavedDrafts.dir.appendingPathComponent("fleet.json") }

    /// Every non-fork repo: file paths with git blob SHAs (one call), README head, bundle ids found in project.yml.
    /// Cached a day: the first read costs about a minute of gh calls.
    static func fleet() async -> [Repo] {
        if let m = (try? cache.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate, -m.timeIntervalSinceNow < 86_400,
           let r = try? JSONDecoder().decode([Repo].self, from: Data(contentsOf: cache)) { return r }
        struct N: Decodable { let name: String; let isFork: Bool; let isArchived: Bool }
        guard let d = try? await ASC.exec(gh, ["repo", "list", owner, "--limit", "200", "--json", "name,isFork,isArchived"], timeout: 60),
              let names = (try? JSONDecoder().decode([N].self, from: d))?.filter({ !$0.isFork && !$0.isArchived }).map(\.name) else { return [] }
        func text(_ args: [String]) async -> String { (try? await ASC.exec(gh, args, timeout: 60)).map { String(decoding: $0, as: UTF8.self) } ?? "" }
        var out: [Repo] = []
        for n in names {
            var files: [String: String] = [:]
            for l in await text(["api", "repos/\(owner)/\(n)/git/trees/HEAD?recursive=1", "--jq", #".tree[]|select(.type=="blob")|"\(.path)\t\(.sha)""#]).split(separator: "\n") {
                let p = l.split(separator: "\t"); if p.count == 2 { files[String(p[0])] = String(p[1]) }
            }
            // Bundle id to the folder its project.yml sits in, so an app inside a monorepo is only its own folder.
            var ids: [String: String] = [:]
            for p in files.keys where p.hasSuffix("project.yml") && p.split(separator: "/").count <= 3 {
                let y = await text(["api", "repos/\(owner)/\(n)/contents/\(p)", "-H", "Accept: application/vnd.github.raw"])
                let dir = (p as NSString).deletingLastPathComponent
                for m in y.matches(of: /com\.[A-Za-z0-9._-]+/) where ids[String(m.output)].map({ dir.count < $0.count }) ?? true { ids[String(m.output)] = dir }
            }
            let readme = await text(["api", "repos/\(owner)/\(n)/readme", "-H", "Accept: application/vnd.github.raw"])
            out.append(Repo(name: n, files: files, readme: String(readme.prefix(1800)), ids: ids))
        }
        try? FileManager.default.createDirectory(at: SavedDrafts.dir, withIntermediateDirectories: true)
        try? JSONEncoder().encode(out).write(to: cache, options: .atomic)
        return out
    }

    /// The other apps on the account, by name, so a reply can say how this one differs from each.
    static func others(than app: ASCApp) async -> String {
        let names = ((try? await ASC.items(["apps", "list", "--paginate"])) ?? []).compactMap { $0.text("name") }.filter { $0 != app.name }
        return names.isEmpty ? "" : "Other apps on this account: \(names.joined(separator: ", "))."
    }

    static func isSource(_ p: String) -> Bool {
        p.hasSuffix(".swift") && !["Test", "Snapshot", "Preview", "build/", ".build/", "Pods/"].contains { p.contains($0) }
    }

    /// The repo and a plain-text fact sheet for one app. Facts only: every line was read, none inferred.
    static func gather(_ app: ASCApp, repo saved: String, fleet: [Repo]) async -> (repo: String, sheet: String) {
        var lines: [String] = [await others(than: app)].filter { !$0.isEmpty }
        if let items = try? await ASC.items(["versions", "list", "--app", app.id]) {
            let v = items.compactMap { i -> (String, String, String)? in
                guard let ver = i.text("versionString") else { return nil }
                return (i.text("platform") ?? "", ver, i.text("appVersionState") ?? i.text("appStoreState") ?? "")
            }
            if let c = items.compactMap({ $0.text("copyright") }).first { lines.append("Copyright on the listing: \(c).") }
            lines.append("App Store history: " + v.map { "\($0.0) \($0.1) \($0.2)" }.joined(separator: "; "))
            let passed = v.filter { ["READY_FOR_SALE", "READY_FOR_DISTRIBUTION", "PENDING_DEVELOPER_RELEASE", "PENDING_APPLE_RELEASE", "PROCESSING_FOR_DISTRIBUTION", "ACCEPTED"].contains($0.2) }
            lines.append(passed.isEmpty ? "No version of this app has been approved yet." : "Approved by App Review before: " + passed.map { "\($0.0) \($0.1)" }.joined(separator: ", "))
        }
        struct B: Decodable { struct D: Decodable { struct A: Decodable { let uploadedDate: String? }; let attributes: A }; let data: [D] }
        if let d = try? await ASC.run(["builds", "list", "--app", app.id, "--limit", "200"]),
           let up = (try? JSONDecoder().decode(B.self, from: d))?.data.compactMap(\.attributes.uploadedDate).sorted(), let first = up.first {
            lines.append("Builds uploaded to App Store Connect and TestFlight: \(up.count), the first on \(first.prefix(10)).")
        }
        let mine = fleet.first { "\(owner)/\($0.name)" == saved }
            ?? fleet.first { $0.ids[app.bundleId] != nil } ?? fleet.first { $0.ids.keys.contains { app.bundleId.hasPrefix($0) || $0.hasPrefix(app.bundleId) } }
        let repo = saved.isEmpty ? (mine.map { "\(owner)/\($0.name)" } ?? "") : saved
        guard let me = mine ?? fleet.first(where: { "\(owner)/\($0.name)" == repo }) else {
            return (repo, lines.joined(separator: "\n") + "\nSource repo: not found, so say nothing about the code.")
        }
        // The app's folders: every top folder whose project.yml carries this bundle id's stem (ios/, macos/, watch/).
        // In a monorepo the folders beside them are other apps; a root project.yml means the whole repo is this app.
        let stem = app.bundleId.split(separator: ".").prefix(3).joined(separator: ".")
        let top = { (p: String) in p.split(separator: "/").first.map(String.init) ?? "" }
        let tops = Set(me.ids.filter { $0.key.hasPrefix(stem) }.map { top($0.value) })
        let whole = tops.isEmpty || tops.contains("")
        let isMine = { (p: String) in whole || tops.contains(top(p)) }
        // Other apps in the same repo: folders whose project.yml names a different app (not Apple's entitlement keys).
        let beside = Set(me.ids.filter { $0.key.split(separator: ".").count >= 3 && !$0.key.hasPrefix("com.apple.") && !$0.key.hasPrefix(stem) }
            .map { top($0.value) }).subtracting(tops).subtracting([""])
        let src = me.files.filter { isSource($0.key) && isMine($0.key) }
        var shared: [String: Set<String>] = [:]
        for o in fleet {
            let same = o.name == me.name
            let shas = Set(o.files.filter { isSource($0.key) && (!same || beside.contains(top($0.key))) }.values)
            for (p, sha) in src where shas.contains(sha) {
                shared[same ? "other \(me.name) folders" : o.name, default: []].insert((p as NSString).lastPathComponent)
            }
        }
        // Store names lag renames (Thinkpond is Melete, Curvely is Pan): say both, so a reply uses the name Apple sees.
        if me.name.lowercased() != app.name.lowercased(), !me.ids.isEmpty, me.name != "labs" {
            lines.append("The listing App Review sees is named \(app.name); the project is now called \(me.name.capitalized). Use \(app.name) in the reply.")
        }
        lines.append("\(app.name) ships \(src.count) Swift source files of its own, written for it.")
        if shared.isEmpty { lines.append("None of its Swift source files is byte-identical to a file in any other app on this account.") }
        else {
            let all = Set(shared.values.flatMap { $0 })
            lines.append("Source files byte-identical to another app in this account: \(all.count) (\(all.sorted().prefix(8).joined(separator: ", "))), shared with \(shared.keys.sorted().joined(separator: ", ")).")
        }
        // In a monorepo the repo README is about the whole repo; the app's own folder README describes the app.
        var readme = me.readme
        if !whole, let t = tops.sorted().first(where: { me.files["\($0)/README.md"] != nil }),
           let d = try? await ASC.exec(gh, ["api", "repos/\(owner)/\(me.name)/contents/\(t)/README.md", "-H", "Accept: application/vnd.github.raw"], timeout: 60) {
            readme = String(String(decoding: d, as: UTF8.self).prefix(1800))
        }
        lines.append("README: " + readme.replacingOccurrences(of: "\n", with: " "))
        return (repo, lines.joined(separator: "\n"))
    }
}
