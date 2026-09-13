import Foundation

/// Tunables passed in, so the reducer never reads a clock or a setting itself.
public struct ReducerConfig: Equatable, Sendable {
    public let capsLockThreshold: TimeInterval

    public init(capsLockThreshold: TimeInterval = 0.3) {
        self.capsLockThreshold = capsLockThreshold
    }
}

/// The new state plus the side effects the data layer must perform.
public struct Reduction: Equatable, Sendable {
    public let state: KeyboardState
    public let intents: [EditorIntent]

    public init(state: KeyboardState, intents: [EditorIntent]) {
        self.state = state
        self.intents = intents
    }
}

/// The whole keyboard input rule, pure and exhaustively testable. When
/// suggestions are active (a suggestable field on the letters page) letters
/// build a composing region and word boundaries finalize it — applying
/// `KeyboardState.autoCorrection`, which the model keeps in sync from the
/// dictionary. Otherwise it commits directly. Either way it only returns
/// `EditorIntent`s; it never touches UIKit.
public enum KeyboardReducer {

    public static func reduce(
        _ state: KeyboardState,
        _ event: KeyboardEvent,
        config: ReducerConfig = ReducerConfig()
    ) -> Reduction {
        var next = state
        switch event {
        case let .keyTapped(lower):
            // Cased as a String, not a Character: uppercasing is allowed to
            // yield more than one character, and `Character(_:)` traps when it
            // does.
            let cased = state.shift == .off ? String(lower) : String(lower).uppercased()
            if state.suggestionsActive && lower.isLetter {
                next.composing = state.composing + cased
                next.shift = consumeOneShot(state.shift)
                return Reduction(state: next, intents: [.setComposing(next.composing)])
            }
            // A non-letter ends the word: finalize it (with autocorrect), then
            // commit the character that ended it.
            if state.suggestionsActive && !state.composing.isEmpty {
                next.composing = ""
                next.autoCorrection = nil
                next.shift = consumeOneShot(state.shift)
                return Reduction(
                    state: next,
                    intents: [.finishComposing(finalWord(state)), .commitText(cased)]
                )
            }
            next.shift = consumeOneShot(state.shift)
            return Reduction(state: next, intents: [.commitText(cased)])

        case let .alternateCommitted(character):
            // Long-press commits verbatim: the alternate is the printed glyph,
            // and shift has no say over it.
            if state.suggestionsActive && !state.composing.isEmpty {
                next.composing = ""
                next.autoCorrection = nil
                return Reduction(
                    state: next,
                    intents: [.finishComposing(state.composing), .commitText(String(character))]
                )
            }
            return Reduction(state: next, intents: [.commitText(String(character))])

        case let .shiftTapped(now):
            let isDouble = state.lastShiftTapAt.map { now - $0 <= config.capsLockThreshold } ?? false
            switch state.shift {
            case .off: next.shift = .shifted
            case .shifted: next.shift = isDouble ? .capsLock : .off
            case .capsLock: next.shift = .off
            }
            next.lastShiftTapAt = now
            return Reduction(state: next, intents: [])

        case .spaceTapped:
            if state.suggestionsActive && !state.composing.isEmpty {
                next.composing = ""
                next.autoCorrection = nil
                next.shift = consumeOneShot(state.shift)
                return Reduction(
                    state: next,
                    intents: [.finishComposing(finalWord(state)), .commitText(" ")]
                )
            }
            next.shift = consumeOneShot(state.shift)
            return Reduction(state: next, intents: [.commitText(" ")])

        case .backspaceTapped:
            if state.suggestionsActive && !state.composing.isEmpty {
                next.composing = String(state.composing.dropLast())
                return Reduction(state: next, intents: [.setComposing(next.composing)])
            }
            return Reduction(state: next, intents: [.deleteBackward])

        // Return settles the word as typed — nobody wants their message sent
        // with a correction they never saw.
        case .enterTapped:
            if state.suggestionsActive && !state.composing.isEmpty {
                next.composing = ""
                next.autoCorrection = nil
                return Reduction(
                    state: next,
                    intents: [.finishComposing(state.composing), .performEnter]
                )
            }
            return Reduction(state: next, intents: [.performEnter])

        case let .pageSwitched(target):
            let finalize: [EditorIntent] = state.composing.isEmpty
                ? []
                : [.finishComposing(state.composing)]
            next.page = target
            next.composing = ""
            next.autoCorrection = nil
            return Reduction(state: next, intents: finalize)

        case let .suggestionChosen(word):
            next.composing = ""
            next.autoCorrection = nil
            return Reduction(
                state: next,
                intents: [.finishComposing(word), .commitText(" ")]
            )
        }
    }

    /// The word a boundary finalizes with: the autocorrection if there is one,
    /// else exactly what was typed.
    private static func finalWord(_ state: KeyboardState) -> String {
        state.autoCorrection ?? state.composing
    }

    /// A one-shot `.shifted` is spent after a single committed character.
    private static func consumeOneShot(_ shift: ShiftState) -> ShiftState {
        shift == .shifted ? .off : shift
    }
}
