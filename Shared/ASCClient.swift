import CryptoKit
import Foundation

// The App Store Connect API, called directly and signed with your own .p8 key. The Mac app runs the asc CLI;
// iOS can't run a CLI, so the phone talks to Apple itself. Reads are GET; every write is one named method below,
// and the app asks before calling any of them.

struct ASCKey: Codable, Equatable {
    let keyID: String
    let issuerID: String
    let pem: String
}

struct ASCError: LocalizedError {
    let status: Int
    let detail: String
    var errorDescription: String? { "App Store Connect said \(status): \(detail)" }
}

struct ASCClient {
    let key: ASCKey
    var session: URLSession = .shared
    static let base = URL(string: "https://api.appstoreconnect.apple.com")!

    /// A 20 minute ES256 token. The signature is the raw 64 byte r||s form JWTs expect, not DER.
    func token(now: Date = Date()) throws -> String {
        let signer = try P256.Signing.PrivateKey(pemRepresentation: key.pem)
        let iat = Int(now.timeIntervalSince1970)
        let header = try JSONSerialization.data(withJSONObject: ["alg": "ES256", "kid": key.keyID, "typ": "JWT"], options: .sortedKeys)
        let claims = try JSONSerialization.data(withJSONObject: ["iss": key.issuerID, "iat": iat, "exp": iat + 1200, "aud": "appstoreconnect-v1"], options: .sortedKeys)
        let input = Self.base64url(header) + "." + Self.base64url(claims)
        let signature = try signer.signature(for: Data(input.utf8))
        return input + "." + Self.base64url(signature.rawRepresentation)
    }

    static func base64url(_ d: Data) -> String {
        d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    /// GET a path like "/v1/apps" with query items. The only verb this client has.
    func get(_ path: String, _ query: [String: String] = [:]) async throws -> Data {
        var c = URLComponents(url: Self.base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { c.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var req = URLRequest(url: c.url!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(try token())", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            struct E: Decodable { struct I: Decodable { let detail: String? ; let title: String? }; let errors: [I]? }
            let msg = (try? JSONDecoder().decode(E.self, from: data))?.errors?.first.map { $0.detail ?? $0.title ?? "" } ?? ""
            throw ASCError(status: status, detail: msg)
        }
        return data
    }

    /// The request behind a write, built separately so tests can check it without sending anything.
    func writeRequest(_ method: String, _ path: String, body: [String: Any]) throws -> URLRequest {
        var req = URLRequest(url: Self.base.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("Bearer \(try token())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: .sortedKeys)
        return req
    }

    func send(_ req: URLRequest) async throws -> Data {
        let (data, resp) = try await session.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            struct E: Decodable { struct I: Decodable { let detail: String?; let title: String? }; let errors: [I]? }
            throw ASCError(status: status, detail: (try? JSONDecoder().decode(E.self, from: data))?.errors?.first.map { $0.detail ?? $0.title ?? "" } ?? "")
        }
        return data
    }

    func decode<T: Decodable>(_ type: T.Type, _ path: String, _ query: [String: String] = [:]) async throws -> T {
        try JSONDecoder().decode(T.self, from: await get(path, query))
    }
}

// MARK: - The few resources the phone shows

struct Doc<A: Decodable>: Decodable {
    struct Item: Decodable, Identifiable { let id: String; let attributes: A }
    let data: [Item]
}

struct AppAttrs: Decodable { let name: String; let bundleId: String }
struct VersionAttrs: Decodable { let platform: String?; let versionString: String?; let appStoreState: String?; let appVersionState: String?; let createdDate: String? }
struct BuildAttrs: Decodable { let version: String?; let uploadedDate: String?; let processingState: String?; let minOsVersion: String? }
struct ReviewAttrs: Decodable { let rating: Int?; let title: String?; let body: String?; let reviewerNickname: String?; let createdDate: String?; let territory: String? }

extension ASCClient {
    func apps() async throws -> [Doc<AppAttrs>.Item] {
        try await decode(Doc<AppAttrs>.self, "/v1/apps", ["limit": "200", "fields[apps]": "name,bundleId"]).data
            .sorted { $0.attributes.name.localizedCaseInsensitiveCompare($1.attributes.name) == .orderedAscending }
    }

    func versions(_ app: String, limit: Int = 50) async throws -> [Doc<VersionAttrs>.Item] {
        try await decode(Doc<VersionAttrs>.self, "/v1/apps/\(app)/appStoreVersions",
                         ["limit": "\(limit)", "fields[appStoreVersions]": "platform,versionString,appStoreState,appVersionState,createdDate"]).data
    }

    func builds(_ app: String) async throws -> [Doc<BuildAttrs>.Item] {
        try await decode(Doc<BuildAttrs>.self, "/v1/builds",
                         ["filter[app]": app, "sort": "-uploadedDate", "limit": "20", "fields[builds]": "version,uploadedDate,processingState,minOsVersion"]).data
    }

    /// The app's icon, from its newest build, at 200 points.
    func icon(_ app: String) async throws -> URL? {
        struct T: Decodable { let templateUrl: String }
        struct A: Decodable { let iconAssetToken: T? }
        let t = try await decode(Doc<A>.self, "/v1/builds", ["filter[app]": app, "sort": "-uploadedDate", "limit": "1", "fields[builds]": "iconAssetToken"])
            .data.first?.attributes.iconAssetToken?.templateUrl
        return t.flatMap { URL(string: $0.replacingOccurrences(of: "{w}x{h}bb.{f}", with: "200x200bb.png")) }
    }

    func reviews(_ app: String) async throws -> [Doc<ReviewAttrs>.Item] {
        try await decode(Doc<ReviewAttrs>.self, "/v1/apps/\(app)/customerReviews", ["sort": "-createdDate", "limit": "50"]).data
    }
}

extension ASCClient {
    static func replyBody(review: String, text: String) -> [String: Any] {
        ["data": ["type": "customerReviewResponses", "attributes": ["responseBody": text],
                  "relationships": ["review": ["data": ["type": "customerReviews", "id": review]]]]]
    }

    /// Publish a reply to a customer review. Apple shows it on the App Store.
    func reply(to review: String, _ text: String) async throws {
        _ = try await send(writeRequest("POST", "/v1/customerReviewResponses", body: Self.replyBody(review: review, text: text)))
    }
}

/// Newest version per platform, from a list the API returns newest first, in a fixed platform order.
func latestPerPlatform(_ versions: [Doc<VersionAttrs>.Item]) -> [Doc<VersionAttrs>.Item] {
    let order = ["IOS", "MAC_OS", "VISION_OS", "TV_OS"]
    var seen = Set<String>()
    return versions.filter { seen.insert($0.attributes.platform ?? "").inserted }
        .sorted { (order.firstIndex(of: $0.attributes.platform ?? "") ?? 9) < (order.firstIndex(of: $1.attributes.platform ?? "") ?? 9) }
}
