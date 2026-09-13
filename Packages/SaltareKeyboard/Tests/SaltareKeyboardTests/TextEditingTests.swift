import XCTest
@testable import SaltareKeyboard

/// The emulated composing region. iOS has no marked-text API for keyboard
/// extensions, so every keystroke of a word is a rewrite of the document tail —
/// and it has to be the *minimal* one.
final class TextEditingTests: XCTestCase {

    func testAppendingALetterIsOneInsertAndNoDeletes() {
        let rewrite = TextEditing.rewrite(from: "hel", to: "hell")
        XCTAssertEqual(rewrite, TextEditing.Rewrite(deleteCount: 0, insert: "l"))
    }

    func testBackspacingIsOneDeleteAndNoInsert() {
        let rewrite = TextEditing.rewrite(from: "hell", to: "hel")
        XCTAssertEqual(rewrite, TextEditing.Rewrite(deleteCount: 1, insert: ""))
    }

    func testAutocorrectRewritesOnlyTheDivergingTail() {
        // "teh" -> "the": the shared "t" stays put.
        XCTAssertEqual(
            TextEditing.rewrite(from: "teh", to: "the"),
            TextEditing.Rewrite(deleteCount: 2, insert: "he")
        )
    }

    func testFinishingAnUnchangedWordIsANoOp() {
        XCTAssertTrue(TextEditing.rewrite(from: "work", to: "work").isEmpty)
    }

    func testDroppingTheWordDeletesAllOfIt() {
        XCTAssertEqual(
            TextEditing.rewrite(from: "work", to: ""),
            TextEditing.Rewrite(deleteCount: 4, insert: "")
        )
    }

    func testCaseChangesCountAsADifference() {
        XCTAssertEqual(
            TextEditing.rewrite(from: "the", to: "The"),
            TextEditing.Rewrite(deleteCount: 3, insert: "The")
        )
    }

    func testAnEmojiCountsAsOneDeletion() {
        // `deleteBackward()` removes a whole character, so the count is in
        // characters — not the UTF-16 units Android has to count.
        XCTAssertEqual(TextEditing.rewrite(from: "ok🔥", to: "ok").deleteCount, 1)
    }
}
