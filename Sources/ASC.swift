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
