import XCTest
@testable import SaltareKeyboard

/// The composing path that backs suggestions and autocorrect, ported from the
/// Android `KeyboardComposingReducerTest`.
final class KeyboardComposingTests: XCTestCase {

    private let suggestable = KeyboardState(fieldSuggestable: true)

    private func reduce(_ state: KeyboardState, _ event: KeyboardEvent) -> Reduction {
        KeyboardReducer.reduce(state, event)
    }

    func testLettersBuildAComposingRegionInsteadOfCommitting() {
        let result = reduce(suggestable, .keyTapped("h"))
        XCTAssertEqual(result.state.composing, "h")
        XCTAssertEqual(result.intents, [.setComposing("h")])
    }

    func testSpaceFinalizesWithTheAutocorrectionWhenPresent() {
        var state = suggestable
        state.composing = "teh"
        state.autoCorrection = "the"
        let result = reduce(state, .spaceTapped)
        XCTAssertEqual(result.intents, [.finishComposing("the"), .commitText(" ")])
        XCTAssertEqual(result.state.composing, "")
        XCTAssertNil(result.state.autoCorrection)
    }

    func testSpaceFinalizesVerbatimWithoutAnAutocorrection() {
        var state = suggestable
        state.composing = "work"
        let result = reduce(state, .spaceTapped)
        XCTAssertEqual(result.intents, [.finishComposing("work"), .commitText(" ")])
    }

    func testBackspaceShrinksTheComposingRegionBeforeDeletingText() {
        var state = suggestable
        state.composing = "hel"
        let mid = reduce(state, .backspaceTapped)
        XCTAssertEqual(mid.state.composing, "he")
        XCTAssertEqual(mid.intents, [.setComposing("he")])

        let empty = reduce(suggestable, .backspaceTapped)
        XCTAssertEqual(empty.intents, [.deleteBackward])
    }

    func testChoosingASuggestionFinalizesWithItAndASpace() {
        var state = suggestable
        state.composing = "th"
        let result = reduce(state, .suggestionChosen("there"))
        XCTAssertEqual(result.intents, [.finishComposing("there"), .commitText(" ")])
        XCTAssertEqual(result.state.composing, "")
    }

    func testEnterCommitsTheWordAsTypedThenPerformsTheAction() {
        var state = suggestable
        state.composing = "teh"
        state.autoCorrection = "the"
        let result = reduce(state, .enterTapped)
        XCTAssertEqual(result.intents, [.finishComposing("teh"), .performEnter])
    }

    func testSwitchingPagesFinalizesTheWordVerbatim() {
        var state = suggestable
        state.composing = "abc"
        let result = reduce(state, .pageSwitched(.symbolsOne))
        XCTAssertEqual(result.intents, [.finishComposing("abc")])
        XCTAssertEqual(result.state.page, .symbolsOne)
    }

    func testANonSuggestableFieldStillCommitsDirectly() {
        let result = reduce(KeyboardState(fieldSuggestable: false), .keyTapped("h"))
        XCTAssertEqual(result.intents, [.commitText("h")])
        XCTAssertEqual(result.state.composing, "")
    }

    func testAPunctuationKeyEndsTheWordAndCommitsItself() {
        var state = suggestable
        state.composing = "teh"
        state.autoCorrection = "the"
        let result = reduce(state, .keyTapped("."))
        XCTAssertEqual(result.intents, [.finishComposing("the"), .commitText(".")])
    }

    func testSuggestionsStopOnTheSymbolsPage() {
        var state = suggestable
        state.page = .symbolsOne
        XCTAssertFalse(state.suggestionsActive)
        XCTAssertEqual(reduce(state, .keyTapped("@")).intents, [.commitText("@")])
    }
}
