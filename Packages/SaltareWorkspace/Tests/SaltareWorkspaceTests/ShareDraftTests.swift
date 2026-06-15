import XCTest
@testable import SaltareWorkspace

final class ShareDraftTests: XCTestCase {
    func testTextOnlyUsesFirstLineAsTitle() {
        let draft = ShareDraft.from(text: "Fix the login bug\nIt 500s on refresh", url: nil)
        XCTAssertEqual(draft.title, "Fix the login bug")
        XCTAssertEqual(draft.body, "Fix the login bug\nIt 500s on refresh")
    }

    func testURLOnlyUsesHostAsTitle() {
        let draft = ShareDraft.from(text: nil, url: "https://example.com/a/b")
        XCTAssertEqual(draft.title, "example.com")
        XCTAssertEqual(draft.body, "https://example.com/a/b")
    }

    func testTextAndURLAppendsURL() {
        let draft = ShareDraft.from(text: "Read this", url: "https://example.com")
        XCTAssertEqual(draft.title, "Read this")
        XCTAssertEqual(draft.body, "Read this\nhttps://example.com")
    }

    func testURLAlreadyInTextIsNotDuplicated() {
        let draft = ShareDraft.from(text: "see https://example.com now", url: "https://example.com")
        XCTAssertEqual(draft.body, "see https://example.com now")
    }

    func testEmptyFallsBackToShared() {
        let draft = ShareDraft.from(text: "   ", url: nil)
        XCTAssertEqual(draft.title, "Shared")
        XCTAssertEqual(draft.body, "")
    }

    func testTitleIsTruncated() {
        let long = String(repeating: "x", count: 200)
        XCTAssertEqual(ShareDraft.from(text: long, url: nil).title.count, 120)
    }
}
