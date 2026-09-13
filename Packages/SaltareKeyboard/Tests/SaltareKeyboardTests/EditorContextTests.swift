import XCTest
@testable import SaltareKeyboard

/// The field policy, ported from the Android `EditorInfoParserTest`. Android
/// reads `EditorInfo` bit flags; iOS reads `UITextInputTraits`, so the shape of
/// the input differs but every decision it drives is the same one.
final class EditorContextTests: XCTestCase {

    func testAPlainTextFieldOpensOnLettersShiftedForASentence() {
        let context = EditorContext.resolve(EditorTraits())
        XCTAssertEqual(context.initialPage, .letters)
        XCTAssertEqual(context.initialShift, .shifted)
        XCTAssertFalse(context.noSuggestions)
    }

    func testAFieldThatAlreadyHasTextIsNotAutoCapitalized() {
        let context = EditorContext.resolve(EditorTraits(hasTextBefore: true))
        XCTAssertEqual(context.initialShift, .off)
    }

    func testAllCharactersLocksCaps() {
        let context = EditorContext.resolve(EditorTraits(capitalization: .allCharacters))
        XCTAssertEqual(context.initialShift, .capsLock)
    }

    func testNumberFieldsOpenOnTheNumericPageWithoutSuggestions() {
        for keyboard in [KeyboardKind.numberPad, .phonePad, .decimalPad, .asciiCapableNumberPad] {
            let context = EditorContext.resolve(EditorTraits(keyboard: keyboard))
            XCTAssertEqual(context.initialPage, .numeric, "\(keyboard)")
            XCTAssertEqual(context.initialShift, .off, "\(keyboard)")
            XCTAssertTrue(context.noSuggestions, "\(keyboard)")
        }
    }

    func testANamePhonePadIsATextFieldNotANumberPad() {
        let context = EditorContext.resolve(EditorTraits(keyboard: .namePhonePad))
        XCTAssertEqual(context.initialPage, .letters)
    }

    func testPasswordFieldsGetNoSuggestionsAndNoAutoCapitals() {
        let context = EditorContext.resolve(
            EditorTraits(capitalization: .sentences, secure: true)
        )
        XCTAssertTrue(context.secure)
        XCTAssertTrue(context.noSuggestions)
        XCTAssertEqual(context.initialShift, .off)
    }

    func testUrlAndEmailFieldsAreNotCorrected() {
        for keyboard in [KeyboardKind.url, .emailAddress] {
            XCTAssertTrue(EditorContext.resolve(EditorTraits(keyboard: keyboard)).noSuggestions, "\(keyboard)")
        }
        // A search field is prose, and keeps them.
        XCTAssertFalse(EditorContext.resolve(EditorTraits(keyboard: .webSearch)).noSuggestions)
    }

    func testAFieldCanRefuseCorrectionOutright() {
        XCTAssertTrue(EditorContext.resolve(EditorTraits(correction: .no)).noSuggestions)
        XCTAssertFalse(EditorContext.resolve(EditorTraits(correction: .yes)).noSuggestions)
    }

    func testEveryReturnKeyResolvesToALabel() {
        XCTAssertEqual(EnterAction(returnKey: .go), .go)
        XCTAssertEqual(EnterAction(returnKey: .search), .search)
        XCTAssertEqual(EnterAction(returnKey: .google), .search)
        XCTAssertEqual(EnterAction(returnKey: .send), .send)
        XCTAssertEqual(EnterAction(returnKey: .done), .done)
        XCTAssertEqual(EnterAction(returnKey: .next), .next)
        XCTAssertEqual(EnterAction(returnKey: .continue), .next)
        XCTAssertEqual(EnterAction(returnKey: .default), .none)

        for key in ReturnKey.allCases {
            XCTAssertFalse(EnterAction(returnKey: key).label.isEmpty, "\(key) has a keycap")
        }
    }

    func testLabelsAreUppercaseHudWords() {
        XCTAssertEqual(EnterAction.go.label, "GO")
        XCTAssertEqual(EnterAction.search.label, "SEARCH")
        XCTAssertEqual(EnterAction.send.label, "SEND")
        XCTAssertEqual(EnterAction.none.label, "ENTER")
    }

    func testASessionStateInheritsTheContext() {
        let context = EditorContext.resolve(EditorTraits(returnKey: .send))
        let state = KeyboardState(context: context)
        XCTAssertEqual(state.enter, .send)
        XCTAssertEqual(state.shift, .shifted)
        XCTAssertTrue(state.suggestionsActive)

        let secure = KeyboardState(context: EditorContext.resolve(EditorTraits(secure: true)))
        XCTAssertFalse(secure.suggestionsActive)
    }
}
