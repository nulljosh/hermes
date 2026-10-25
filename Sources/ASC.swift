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
    static var readOnly: Bool { UserDefaults.standard.object(forKey: "readOnly") as? Bool ?? true }
    // The asc profile picked in the sidebar; empty means asc's own default.
    static var profile: String { UserDefaults.standard.string(forKey: "profile") ?? "" }

    static func run(_ args: [String], json: Bool = true, timeout: Double? = nil) async throws -> Data {
        // Read-only mode (Settings, on by default) makes asc refuse every write before it is sent.
        try await exec("/opt/homebrew/bin/asc",
                       (readOnly ? ["--read-only"] : []) + (profile.isEmpty ? [] : ["--profile", profile]) + args + (json ? ["--output", "json"] : []),
                       timeout: timeout)
    }

    /// Runs a tool and returns its stdout. No stdin, so nothing can sit waiting on a prompt;
    /// with a timeout, a stalled run (a web session asking for 2FA) is killed instead of freezing the window.
    static func exec(_ path: String, _ args: [String], cwd: URL? = nil, timeout: Double? = nil, env: [String: String] = [:]) async throws -> Data {
        try await Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: path)
            p.arguments = args
            p.currentDirectoryURL = cwd
            // asc signs in to Apple's web session on its own when it expires; the 2FA code comes from Hermes' own prompt.
            p.environment = ProcessInfo.processInfo.environment.merging(["ASC_BYPASS_KEYCHAIN": "1", "ASC_TIMEOUT": "240s",
                                                                         "ASC_WEB_2FA_CODE_COMMAND": TwoFactor.script]) { $1 }
                .merging(env) { $1 }
            let out = Pipe(), err = Pipe()
            p.standardOutput = out; p.standardError = err; p.standardInput = FileHandle.nullDevice
            try p.run()
            if let timeout { DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { if p.isRunning { p.terminate() } } }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            let msg = err.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            if p.terminationReason == .uncaughtSignal {
                let tool = URL(fileURLWithPath: path).lastPathComponent
                throw NSError(domain: "asc", code: -1, userInfo: [NSLocalizedDescriptionKey: "\(tool) took too long."
                    + (tool == "asc" ? " If it was signing in to Apple, run asc-login in Terminal and try again." : "")])
            }
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
    func bool(_ key: String) -> Bool {
        if case .b(let v)? = attributes?[key] { return v }
        return false
    }
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

    static func one(_ args: [String]) async throws -> Item? {
        struct R: Decodable { let data: Item? }
        return try JSONDecoder().decode(R.self, from: await run(args)).data
    }

    static func versions(_ id: String) async throws -> [PlatformVersion] {
        try await items(["versions", "list", "--app", id, "--latest"]).compactMap {
            guard let p = $0.text("platform"), let v = $0.text("versionString") else { return nil }
            return PlatformVersion(platform: p, version: v, state: $0.text("appVersionState") ?? $0.text("appStoreState") ?? "")
        }.sorted { $0.platform < $1.platform }
    }

    // The icon Apple pulled out of the newest build; works for apps that are not on sale yet.
    static func buildIcon(_ id: String) async -> URL? {
        struct R: Decodable {
            struct D: Decodable { struct A: Decodable { struct T: Decodable { let templateUrl: String }; let iconAssetToken: T? }; let attributes: A }
            let data: [D]
        }
        guard let data = try? await run(["builds", "list", "--app", id, "--limit", "1"]),
              let t = (try? JSONDecoder().decode(R.self, from: data))?.data.first?.attributes.iconAssetToken?.templateUrl else { return nil }
        return URL(string: t.replacingOccurrences(of: "{w}x{h}bb.{f}", with: "200x200bb.png"))
    }

    // Store artwork for live apps; the UI falls back to buildIcon, then a letter tile.
    static func icon(bundleId: String) async -> URL? {
        guard let u = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)&entity=software"),
              let (d, _) = try? await URLSession.shared.data(from: u),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let r = (o["results"] as? [[String: Any]])?.first,
              let s = r["artworkUrl100"] as? String else { return nil }
        return URL(string: s)
    }
}

extension ASC {
    struct Profile: Decodable, Hashable { let name: String; let isDefault: Bool? }

    // Accounts asc knows about. Only names come back here; keys never leave asc.
    static func profiles() async -> [Profile] {
        struct R: Decodable { let credentials: [Profile]? }
        guard let data = try? await run(["auth", "status"]) else { return [] }
        return (try? JSONDecoder().decode(R.self, from: data))?.credentials ?? []
    }
}
