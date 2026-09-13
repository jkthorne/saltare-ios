/// Side-effect descriptors the reducer returns. The data layer (the extension's
/// `TextDocumentGateway`) is the only thing that turns these into
/// `UITextDocumentProxy` calls — the reducer never touches UIKit.
///
/// `setComposing`/`finishComposing` carry the *whole* in-progress word rather
/// than a delta: iOS gives a keyboard extension no marked-text API, so the
/// gateway emulates the composing region by rewriting the tail of the document
/// (see `TextEditing.rewrite`), and it can only do that against the full word.
public enum EditorIntent: Equatable, Sendable {
    case commitText(String)
    /// Make the in-progress word read as `text`.
    case setComposing(String)
    /// Settle the in-progress word as `text` and stop tracking it (this is where
    /// an autocorrection is applied).
    case finishComposing(String)
    case deleteBackward
    case performEnter
}
