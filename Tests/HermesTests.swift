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

    // Writes are built separately from sending, so the shape Apple expects is checked without touching a live app.
    func testReplyRequestShape() throws {
        let client = ASCClient(key: ASCKey(keyID: "K", issuerID: "I", pem: P256.Signing.PrivateKey().pemRepresentation))
        let req = try client.writeRequest("POST", "/v1/customerReviewResponses", body: ASCClient.replyBody(review: "rev1", text: "Thanks!"))
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.url?.absoluteString, "https://api.appstoreconnect.apple.com/v1/customerReviewResponses")
        XCTAssertTrue(req.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") ?? false)
        let body = try JSONSerialization.jsonObject(with: req.httpBody!) as! [String: Any]
        let data = body["data"] as! [String: Any]
        XCTAssertEqual(data["type"] as? String, "customerReviewResponses")
        XCTAssertEqual((data["attributes"] as! [String: Any])["responseBody"] as? String, "Thanks!")
        let rel = ((data["relationships"] as! [String: Any])["review"] as! [String: Any])["data"] as! [String: Any]
        XCTAssertEqual(rel["id"] as? String, "rev1")
        XCTAssertEqual(rel["type"] as? String, "customerReviews")
    }

    // Shape of a real `asc web review show --plain-text` (Curbfind, 4.3), text scrubbed. Apple wrote last, so it is ours to answer.
    func testResolveAllPicksThreadsAppleIsWaitingOn() throws {
        func show(state: String, lastFrom: String) -> String {
            #"{"submission":{"state":"\#(state)","appStoreVersionForReview":{"version":"1.0.0"}},"threads":[{"thread":{"id":"t1","canDeveloperAddNote":true},"#
            + #""messages":[{"createdDate":"2026-10-05T21:20:34Z","messageBodyPlain":"Guideline 4.3","fromActor":{"actorType":"APPLE"}},"#
            + #"{"createdDate":"2026-10-06T01:00:55Z","messageBodyPlain":"It is original.","fromActor":{"actorType":"USER"}},"#
            + #"{"createdDate":"2026-10-13T21:31:23Z","messageBodyPlain":"More on 4.3","fromActor":{"actorType":"\#(lastFrom)"}}],"#
            + #""rejections":[{"reasons":[{"reasonSection":"4.3","reasonDescription":"Design: Spam","reasonCode":"4.3.0"}]}]}]}"#
        }
        let ours = try JSONDecoder().decode(ReviewShow.self, from: Data(show(state: "UNRESOLVED_ISSUES", lastFrom: "APPLE").utf8))
        let o = try XCTUnwrap(ours.open())
        XCTAssertEqual(o.thread.thread.id, "t1")
        XCTAssertEqual(o.apple, "More on 4.3")
        XCTAssertTrue(o.replied)
        XCTAssertFalse(o.waiting)
        XCTAssertEqual(ours.reasons, ["4.3 Design: Spam"])

        let theirs = try JSONDecoder().decode(ReviewShow.self, from: Data(show(state: "UNRESOLVED_ISSUES", lastFrom: "USER").utf8))
        XCTAssertEqual(theirs.open()?.waiting, true)
        XCTAssertEqual(theirs.open()?.apple, "Guideline 4.3")

        let done = try JSONDecoder().decode(ReviewShow.self, from: Data(show(state: "COMPLETE", lastFrom: "APPLE").utf8))
        XCTAssertNil(done.open())

        var r = Resolution(app: ASCApp(id: "1", name: "Curbfind", bundleId: "x"), thread: "t1", version: "1.0.0", reasons: [], apple: "", replied: true, repo: "")
        r.reply = "We changed [what]."
        XCTAssertTrue(r.unfilled)
        r.reply = "We changed the map."
        XCTAssertFalse(r.unfilled)
    }

    // A drafted reply never claims a change nobody made: the claim becomes a placeholder, which blocks Send.
    func testDraftClaimsAreDropped() {
        let d = Drafter.unclaim("Thank you for the review. We have revised the app to add features. We've also fixed the crash. Please take another look.")
        XCTAssertEqual(d, "Thank you for the review. Please take another look.")
        XCTAssertEqual(Drafter.unclaim("Thanks. The app is different from others because it reads live rentals."),
                       "Thanks. The app is different from others because it reads live rentals.")
        XCTAssertEqual(Drafter.unclaim(""), "")
    }

    // An expired Apple web session stops Resolve All once instead of failing every app the same way.
    func testSessionErrorsAreSeparatedFromAppErrors() {
        func e(_ m: String) -> Error { NSError(domain: "asc", code: 2, userInfo: [NSLocalizedDescriptionKey: m]) }
        XCTAssertTrue(AppleWeb.isSessionError(e("Session expired.\nError: no usable Apple web session for a@b.com")))
        XCTAssertTrue(AppleWeb.isSessionError(e("Error: web auth login failed: 2fa required")))
        XCTAssertFalse(AppleWeb.isSessionError(e("Error: app not found")))
    }

    func testSavedDraftsRetireOnANewAppleMessage() {
        var r = Resolution(app: ASCApp(id: "1", name: "Cartons", bundleId: "b"), thread: "t1", version: "1.0.0",
                           reasons: ["4.3 Design: Spam"], apple: "Hello", replied: false, repo: "")
        let k = SavedDrafts.key(r)
        r.reply = "Cartons tracks UPS parcels."
        XCTAssertTrue(SavedDrafts.dryRun([r]).contains("## Cartons 1.0.0"))
        XCTAssertTrue(SavedDrafts.dryRun([r]).contains("> Hello"))
        let newer = Resolution(app: r.app, thread: "t1", version: "1.0.0", reasons: [], apple: "Hello again", replied: false, repo: "")
        XCTAssertNotEqual(k, SavedDrafts.key(newer))
    }

    func testThrottleWaitsForAsc() {
        func e(_ m: String) -> Error { NSError(domain: "asc", code: 1, userInfo: [NSLocalizedDescriptionKey: m]) }
        let d = AppleWeb.throttledUntil(e("signin complete failed with status 503. Other asc web commands will not sign in automatically before 2026-10-25T18:22:53Z;"))
        XCTAssertEqual(d, ISO8601DateFormatter().date(from: "2026-10-25T18:22:53Z"))
        XCTAssertNotNil(AppleWeb.throttledUntil(e("Apple's sign-in service is unavailable or is throttling sign-ins")))
        XCTAssertNil(AppleWeb.throttledUntil(e("Session expired.")))
    }

    func testWriterSplitsApplesQuestionsAndCutsRepeats() {
        let apple = "Next Steps\n1. Describe in detail what this app does.\n2. Who is the intended user\nof this app?\nResources\n- Learn more"
        XCTAssertEqual(Writer.questions(apple), ["Describe in detail what this app does.", "Who is the intended user of this app?"])
        XCTAssertEqual(Writer.focus("Is this app part of a suite? Is it standalone?").readme, false)
        XCTAssertEqual(Writer.focus("Who is the intended user of this app?").readme, true)
        let earlier = ["1. Sidewise pulls 16 feeds from 14 newsrooms across the spectrum."]
        XCTAssertEqual(Writer.fresh("It is for news readers. Sidewise pulls 16 feeds from 14 newsrooms across the spectrum.", after: earlier),
                       "It is for news readers.")
    }

    func testKnownFixesMatchApplesWording() {
        XCTAssertEqual(Writer.knownFixes("We were unable to access the app because we were unable to bypass the keychain request.").count, 1)
        XCTAssertEqual(Writer.knownFixes("the app displayed an error message when we attempted to create an account using Sign in with Apple").count, 1)
        XCTAssertTrue(Writer.knownFixes("Guideline 4.3(a) - Design - Spam").isEmpty)
    }

    func testWatchOnlyReportsRealMoves() {
        let old = ["1|IOS": "WAITING_FOR_REVIEW", "2|MAC_OS": "REJECTED"]
        let new = ["1|IOS": "IN_REVIEW", "2|MAC_OS": "REJECTED", "3|IOS": "PREPARE_FOR_SUBMISSION"]
        XCTAssertEqual(Watch.changes(from: old, to: new), [Watch.Change(key: "1|IOS", from: "WAITING_FOR_REVIEW", to: "IN_REVIEW")])
        XCTAssertEqual(Watch.words("WAITING_FOR_REVIEW"), "waiting for review")
    }

    func testAgreementBannerOnlyWhenSomethingWaits() {
        let ok = #"{"pending":false,"contractMessages":[],"agreements":[{"title":"Apple Developer Program License Agreement","status":"active","pending":false,"dateAgreeBy":"2026-10-28T23:59:59Z"}]}"#
        XCTAssertNil(Agreements.notice(from: Data(ok.utf8)))
        let waiting = ok.replacingOccurrences(of: #""status":"active","pending":false"#, with: #""status":"pending","pending":true"#)
        XCTAssertEqual(Agreements.notice(from: Data(waiting.utf8)),
                       "Apple has a new Apple Developer Program License Agreement to accept by 2026-10-28. Until you do, nothing can be submitted.")
    }

    func testSalesSummaryCountsDownloadsNotUpdates() {
        let tsv = "Provider\tTitle\tProduct Type Identifier\tUnits\tDeveloper Proceeds\tApple Identifier\n" +
                  "APPLE\tAtlin\t1F\t12\t0\t6824157219\n" +
                  "APPLE\tAtlin\t3F\t2\t0\t6824157219\n" +
                  "APPLE\tAtlin\t7F\t40\t0\t6824157219\n" +
                  "APPLE\tTalli\t1F\t5\t0.99\t6782366555\n"
        let rows = Sales.parse(tsv)
        XCTAssertEqual(Sales.totals(rows, app: "6824157219"), Sales.Totals(downloads: 12, redownloads: 2, proceeds: 0))
        XCTAssertEqual(Sales.totals(rows, app: "6782366555").proceeds, 4.95, accuracy: 0.001)
    }

    func testValidationDecodesAscOutput() throws {
        let j = #"{"platform":"MAC_OS","versionString":"1.0.0","summary":{"errors":0,"warnings":0,"infos":1,"blocking":0},"remediation":{"totalActionable":1,"steps":[{"order":1,"blocking":false,"severity":"info","message":"App Privacy publish state is not verifiable","remediation":"Confirm App Privacy is published"}]}}"#
        let v = try JSONDecoder().decode(Validation.self, from: Data(j.utf8))
        XCTAssertEqual(v.verdict, "Ready to submit")
        XCTAssertEqual(v.remediation?.steps.first?.order, 1)
    }

    func testKeywordAuditFlagsWordsAlreadyInTheName() throws {
        let j = #"{"platform":"IOS","versionString":"1.0.0","locales":[{"locale":"en-US","keywordField":"rent,atlin,map,deal","keywordCount":4,"usedBytes":18,"remainingBytes":82,"name":"Atlin","subtitle":"Real rentals ranked by deal"}],"checks":[]}"#
        let a = try JSONDecoder().decode(KeywordAudit.self, from: Data(j.utf8))
        XCTAssertEqual(a.locales.first?.repeats, ["atlin", "deal"])
    }
}
