import Foundation

// Thin wrapper over the `asc` CLI: it owns auth, we just render its JSON.
struct ASCApp: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let bundleId: String
}

struct Status: Decodable {
    struct Summary: Decodable { let health: String?; let nextAction: String?; let blockers: [String]? }
    struct Build: Decodable { let version: String?; let buildNumber: String?; let processingState: String?; let platform: String? }
    struct Store: Decodable { let version: String?; let state: String?; let platform: String? }
    struct Review: Decodable { let state: String?; let submittedDate: String? }
    struct Links: Decodable { let appStoreConnect: String?; let testFlight: String?; let review: String? }
    struct Builds: Decodable { let latest: Build? }
    let summary: Summary
    let builds: Builds?
    let appstore: Store?
    let review: Review?
    let links: Links?
}

enum ASC {
    static func run(_ args: [String]) async throws -> Data {
        try await Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/asc")
            p.arguments = args + ["--output", "json"]
            p.environment = ProcessInfo.processInfo.environment.merging(["ASC_BYPASS_KEYCHAIN": "1"]) { $1 }
            let out = Pipe(), err = Pipe()
            p.standardOutput = out; p.standardError = err
            try p.run()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            let msg = err.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else {
                throw NSError(domain: "asc", code: Int(p.terminationStatus),
                              userInfo: [NSLocalizedDescriptionKey: String(decoding: msg, as: UTF8.self)])
            }
            return data
        }.value
    }

    static func apps() async throws -> [ASCApp] {
        struct R: Decodable {
            struct D: Decodable { struct A: Decodable { let name: String; let bundleId: String }; let id: String; let attributes: A }
            let data: [D]
        }
        let r = try JSONDecoder().decode(R.self, from: await run(["apps", "list", "--paginate"]))
        return r.data.map { ASCApp(id: $0.id, name: $0.attributes.name, bundleId: $0.attributes.bundleId) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func status(_ id: String) async throws -> Status {
        try JSONDecoder().decode(Status.self, from: await run(["status", "--app", id]))
    }
}

// MARK: - Per-platform versions, generic items, icons

struct PlatformVersion: Identifiable {
    let platform: String, version: String, state: String
    var id: String { platform }
}

enum Scalar: Decodable, CustomStringConvertible {
    case s(String), n(Double), b(Bool), null
    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if let v = try? c.decode(String.self) { self = .s(v) }
        else if let v = try? c.decode(Double.self) { self = .n(v) }
        else if let v = try? c.decode(Bool.self) { self = .b(v) }
        else { self = .null }
    }
    var description: String {
        switch self {
        case .s(let v): v
        case .n(let v): v == v.rounded() ? String(Int(v)) : String(v)
        case .b(let v): v ? "yes" : "no"
        case .null: ""
        }
    }
}

struct Item: Decodable, Identifiable {
    let id: String
    let attributes: [String: Scalar]?
    func text(_ key: String) -> String? {
        guard let t = attributes?[key]?.description, !t.isEmpty else { return nil }
        return t
    }
}

extension ASC {
    static func items(_ args: [String]) async throws -> [Item] {
        struct R: Decodable { let data: [Item]?; let items: [Item]? }
        let r = try JSONDecoder().decode(R.self, from: await run(args))
        return r.data ?? r.items ?? []
    }

    static func versions(_ id: String) async throws -> [PlatformVersion] {
        try await items(["versions", "list", "--app", id, "--latest"]).compactMap {
            guard let p = $0.text("platform"), let v = $0.text("versionString") else { return nil }
            return PlatformVersion(platform: p, version: v, state: $0.text("appVersionState") ?? $0.text("appStoreState") ?? "")
        }.sorted { $0.platform < $1.platform }
    }

    // Live apps only; unreleased ones fall back to a letter tile in the UI.
    static func icon(bundleId: String) async -> URL? {
        guard let u = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)&entity=software"),
              let (d, _) = try? await URLSession.shared.data(from: u),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let r = (o["results"] as? [[String: Any]])?.first,
              let s = r["artworkUrl100"] as? String else { return nil }
        return URL(string: s)
    }
}
