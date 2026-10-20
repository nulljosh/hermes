import CryptoKit
import SwiftUI
import XCTest
@testable import Hermes

// The logic the UI leans on: state colours, the confirm-dialog command line, lossy decoding, CDN thumbnails.
final class HermesTests: XCTestCase {
    func testStateColors() {
        XCTAssertEqual(Theme.stateColor("READY_FOR_DISTRIBUTION"), Theme.live)
        XCTAssertEqual(Theme.stateColor("WAITING_FOR_REVIEW"), Theme.pending)
        XCTAssertEqual(Theme.stateColor("PROCESSING_FOR_DISTRIBUTION"), Theme.pending)
        XCTAssertEqual(Theme.stateColor("REJECTED"), Theme.bad)
        XCTAssertEqual(Theme.stateColor("METADATA_REJECTED"), Theme.bad)
        XCTAssertEqual(Theme.stateColor("INVALID_BINARY"), Theme.bad)
        XCTAssertEqual(Theme.stateColor("PREPARE_FOR_SUBMISSION"), Theme.idle)
        XCTAssertEqual(Theme.stateColor(nil), Theme.idle)
        XCTAssertEqual(Theme.platform("MAC_OS"), "macOS")
    }

    func testCommandLineQuotesAndChains() {
        let one = PendingCommand(title: "Save", args: ["versions", "update", "--copyright", "2026 Joshua Trommel"])
        XCTAssertEqual(one.line, "asc versions update --copyright \"2026 Joshua Trommel\"")
        let two = PendingCommand(title: "Create", args: ["review", "submissions-create"], then: ["review", "items-add", "--submission", "{id}"])
        XCTAssertEqual(two.line, "asc review submissions-create\nthen asc review items-add --submission {id}")
    }

    func testItemDecodesMixedAttributes() throws {
        let json = #"{"id":"a","attributes":{"name":"Icelus","rating":5,"expired":false,"empty":"","gone":null,"nested":{"x":1}}}"#
        let item = try JSONDecoder().decode(Item.self, from: Data(json.utf8))
        XCTAssertEqual(item.text("name"), "Icelus")
        XCTAssertEqual(item.text("rating"), "5")
        XCTAssertFalse(item.bool("expired"))
        XCTAssertNil(item.text("empty"))
        XCTAssertNil(item.text("gone"))
        XCTAssertNil(item.text("nested"))
    }

    func testThumbnailURL() throws {
        let json = #"{"id":"s","attributes":{"imageAsset":{"templateUrl":"https://x/{w}x{h}bb.{f}","width":1284,"height":2778}}}"#
        let asset = try JSONDecoder().decode(Asset.self, from: Data(json.utf8))
        XCTAssertEqual(asset.thumb(height: 220)?.absoluteString, "https://x/202x440bb.png")
    }

    func testRejectedSubmission() throws {
        let json = #"[{"submissionId":"1","state":"COMPLETE","outcome":"rejected"},{"submissionId":"2","state":"COMPLETE","outcome":"approved"}]"#
        let subs = try JSONDecoder().decode([Submission].self, from: Data(json.utf8))
        XCTAssertTrue(subs[0].rejected)
        XCTAssertFalse(subs[1].rejected)
    }

    // The iOS client signs its own requests: ES256, raw r||s signature, 20 minute expiry, Apple's audience.
    func testAPITokenVerifiesAndCarriesClaims() throws {
        let pk = P256.Signing.PrivateKey()
        let client = ASCClient(key: ASCKey(keyID: "ABC123", issuerID: "issuer-1", pem: pk.pemRepresentation))
        let parts = try client.token(now: Date(timeIntervalSince1970: 1_000)).split(separator: ".").map(String.init)
        XCTAssertEqual(parts.count, 3)
        func json(_ s: String) throws -> [String: Any] {
            var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            while b.count % 4 != 0 { b += "=" }
            return try JSONSerialization.jsonObject(with: Data(base64Encoded: b)!) as! [String: Any]
        }
        let header = try json(parts[0]), claims = try json(parts[1])
        XCTAssertEqual(header["alg"] as? String, "ES256")
        XCTAssertEqual(header["kid"] as? String, "ABC123")
        XCTAssertEqual(claims["iss"] as? String, "issuer-1")
        XCTAssertEqual(claims["aud"] as? String, "appstoreconnect-v1")
        XCTAssertEqual(claims["exp"] as? Int, 2_200)
        var sig = parts[2].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while sig.count % 4 != 0 { sig += "=" }
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: Data(base64Encoded: sig)!)
        XCTAssertTrue(pk.publicKey.isValidSignature(signature, for: Data((parts[0] + "." + parts[1]).utf8)))
    }

    func testLatestPerPlatformKeepsNewestOfEach() throws {
        let json = #"{"data":[{"id":"1","attributes":{"platform":"IOS","versionString":"2.0"}},{"id":"2","attributes":{"platform":"MAC_OS","versionString":"1.5"}},{"id":"3","attributes":{"platform":"IOS","versionString":"1.9"}}]}"#
        let doc = try JSONDecoder().decode(Doc<VersionAttrs>.self, from: Data(json.utf8))
        XCTAssertEqual(latestPerPlatform(doc.data).map(\.id), ["1", "2"])
    }
}
