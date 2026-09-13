import XCTest
@testable import SaltareKeyboard

/// Ported from the Android `:keyboard` `KeyboardReducerTest`. The whole input
/// rule lives in `KeyboardReducer.reduce`, so none of this needs a keyboard.
final class KeyboardReducerTests: XCTestCase {

    private let config = ReducerConfig(capsLockThreshold: 0.3)

    private func tap(_ state: KeyboardState, _ character: Character) -> Reduction {
        KeyboardReducer.reduce(state, .keyTapped(character), config: config)
    }

    private func shift(_ state: KeyboardState, at now: TimeInterval) -> Reduction {
        KeyboardReducer.reduce(state, .shiftTapped(now: now), config: config)
    }

    func testUnshiftedLetterCommitsLowercase() {
        let result = tap(KeyboardState(), "q")
        XCTAssertEqual(result.intents, [.commitText("q")])
        XCTAssertEqual(result.state.shift, .off)
    }

    func testOneShotShiftCommitsUppercaseThenReleases() {
        let shifted = shift(KeyboardState(), at: 1.0).state
        XCTAssertEqual(shifted.shift, .shifted)

        let result = tap(shifted, "q")
        XCTAssertEqual(result.intents, [.commitText("Q")])
        XCTAssertEqual(result.state.shift, .off, "shift is consumed after one character")
    }

    func testDoubleTapShiftLocksCapsAndSurvivesTyping() {
        var state = KeyboardState()
        state = shift(state, at: 1.0).state   // off -> shifted
        state = shift(state, at: 1.1).state   // a quick second tap -> caps lock
        XCTAssertEqual(state.shift, .capsLock)

        let first = tap(state, "a")
        XCTAssertEqual(first.intents, [.commitText("A")])
        XCTAssertEqual(first.state.shift, .capsLock, "caps lock is not consumed")

        let second = tap(first.state, "b")
        XCTAssertEqual(second.intents, [.commitText("B")])
        XCTAssertEqual(second.state.shift, .capsLock)
    }

    func testSlowSecondShiftTapTurnsShiftOffNotCaps() {
        var state = KeyboardState()
        state = shift(state, at: 1.0).state
        state = shift(state, at: 2.0).state   // a second later: past the threshold
        XCTAssertEqual(state.shift, .off)
    }

    func testCapsLockTogglesOffOnTheNextShiftTap() {
        let state = shift(KeyboardState(shift: .capsLock), at: 5.0).state
        XCTAssertEqual(state.shift, .off)
    }

    func testSpaceCommitsSpaceAndConsumesOneShotShift() {
        let result = KeyboardReducer.reduce(KeyboardState(shift: .shifted), .spaceTapped, config: config)
        XCTAssertEqual(result.intents, [.commitText(" ")])
        XCTAssertEqual(result.state.shift, .off)
    }

    func testBackspaceAndEnterEmitTheirIntents() {
        XCTAssertEqual(
            KeyboardReducer.reduce(KeyboardState(), .backspaceTapped, config: config).intents,
            [.deleteBackward]
        )
        XCTAssertEqual(
            KeyboardReducer.reduce(KeyboardState(), .enterTapped, config: config).intents,
            [.performEnter]
        )
    }

    func testSwitchingPageChangesPageWithoutSideEffects() {
        let result = KeyboardReducer.reduce(KeyboardState(), .pageSwitched(.symbolsOne), config: config)
        XCTAssertEqual(result.state.page, .symbolsOne)
        XCTAssertEqual(result.intents, [])
    }

    func testSymbolKeyCommitsVerbatim() {
        let result = tap(KeyboardState(page: .symbolsOne), "@")
        XCTAssertEqual(result.intents, [.commitText("@")])
    }

    func testAlternateCommitsVerbatimAndLeavesShiftUntouched() {
        let result = KeyboardReducer.reduce(
            KeyboardState(shift: .capsLock),
            .alternateCommitted("1"),
            config: config
        )
        XCTAssertEqual(result.intents, [.commitText("1")])
        XCTAssertEqual(result.state.shift, .capsLock)
    }
}
