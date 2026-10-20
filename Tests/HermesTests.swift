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
}
