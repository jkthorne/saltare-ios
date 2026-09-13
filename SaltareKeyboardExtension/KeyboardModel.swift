import Foundation
import SaltareKeyboard

/// Orchestrates the pure reducer, the document gateway, and the dictionary —
/// the iOS counterpart of the Android `KeyboardViewModel`. After every event it
/// recomputes the strip and keeps `KeyboardState.autoCorrection` in sync: that
/// is the value the reducer reads when it finalizes the next word.
@MainActor
@Observable
final class KeyboardModel {

    private(set) var state = KeyboardState()
    private(set) var suggestions: [String] = []
    private(set) var autoCorrect: String?

    /// Whether to draw the next-keyboard key (`needsInputModeSwitchKey`).
    var needsGlobe = false

    @ObservationIgnored var gateway: TextDocumentGateway?
    @ObservationIgnored var switchKeyboard: (@MainActor () -> Void)?
    @ObservationIgnored private var suggester: Suggester?
    @ObservationIgnored private let config = ReducerConfig()

    var rows: [[Key]] { Layouts.rows(state.page, globe: needsGlobe) }

    /// A new input session: resolve the field and reset everything transient.
    func startSession(_ traits: EditorTraits) {
        state = KeyboardState(context: EditorContext.resolve(traits))
        refresh()
    }

    func handle(_ event: KeyboardEvent) {
        let reduction = KeyboardReducer.reduce(state, event, config: config)
        state = reduction.state
        for intent in reduction.intents {
            gateway?.perform(intent)
        }
        refresh()
    }

    /// The word list arrives after the keyboard does (30k lines parse off the
    /// main thread); until it does, the keyboard types but does not suggest.
    func adopt(_ suggester: Suggester) {
        self.suggester = suggester
        refresh()
    }

    /// Drop the word in progress when the document no longer ends with it —
    /// the host moved the cursor, or changed the text itself, and the composing
    /// region we think we own is no longer there.
    func dropComposingIfDetached(from documentBeforeInput: String?) {
        guard !state.composing.isEmpty else { return }
        guard let gateway, !(documentBeforeInput ?? "").hasSuffix(gateway.composingText) else { return }
        gateway.reset()
        state.composing = ""
        state.autoCorrection = nil
        refresh()
    }

    private func refresh() {
        guard state.suggestionsActive, !state.composing.isEmpty, let suggester else {
            state.autoCorrection = nil
            suggestions = []
            autoCorrect = nil
            return
        }
        let result = suggester.suggest(state.composing)
        state.autoCorrection = result.autoCorrection
        suggestions = result.strip
        autoCorrect = result.autoCorrection
    }
}
