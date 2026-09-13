import UIKit
import SaltareKeyboard

/// The only translator of `EditorIntent`s into `UITextDocumentProxy` calls. The
/// proxy is fetched live through a closure because the system swaps it between
/// input sessions.
///
/// It also owns the emulated composing region. iOS offers a keyboard extension
/// no marked text, so "the word being typed" is not a thing the system tracks
/// for us: this class remembers what it inserted for the current word and
/// rewrites that tail (`TextEditing.rewrite`) whenever the word changes. Getting
/// that wrong is how a keyboard eats the text in front of it, so nothing else
/// is allowed to touch the document.
@MainActor
final class TextDocumentGateway {

    private let proxy: @MainActor () -> UITextDocumentProxy?
    private var composing = ""

    /// What the gateway believes it has standing in the document for the word in
    /// progress — the controller checks this against the real document when
    /// something else moves the cursor.
    var composingText: String { composing }

    init(proxy: @escaping @MainActor () -> UITextDocumentProxy?) {
        self.proxy = proxy
    }

    func perform(_ intent: EditorIntent) {
        guard let proxy = proxy() else { return }
        switch intent {
        case let .commitText(text):
            composing = ""
            proxy.insertText(text)
        case let .setComposing(text):
            rewrite(to: text, on: proxy)
        case let .finishComposing(text):
            rewrite(to: text, on: proxy)
            composing = ""
        case .deleteBackward:
            proxy.deleteBackward()
        case .performEnter:
            // A keyboard extension cannot invoke the field's return action the
            // way Android's `performDefaultEditorAction` can. A newline is what
            // the host's own delegate reads as "return was pressed".
            composing = ""
            proxy.insertText("\n")
        }
    }

    /// Forget the word in progress without editing the document — a new input
    /// session, or a cursor that moved out from under us.
    func reset() {
        composing = ""
    }

    private func rewrite(to target: String, on proxy: UITextDocumentProxy) {
        let edit = TextEditing.rewrite(from: composing, to: target)
        for _ in 0..<edit.deleteCount {
            proxy.deleteBackward()
        }
        if !edit.insert.isEmpty {
            proxy.insertText(edit.insert)
        }
        composing = target
    }
}
