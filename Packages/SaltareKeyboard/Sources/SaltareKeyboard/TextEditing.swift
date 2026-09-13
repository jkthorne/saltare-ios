/// Pure text edits the gateway needs. There is no counterpart to the Android
/// port's surrogate-pair arithmetic: `UITextDocumentProxy.deleteBackward()`
/// already removes one whole character (emoji included), whereas Android's
/// `deleteSurroundingText` counts UTF-16 units and has to be told.
public enum TextEditing {

    /// How to turn the text currently standing in the document into `target`:
    /// delete this many characters backwards, then insert this string.
    public struct Rewrite: Equatable, Sendable {
        public let deleteCount: Int
        public let insert: String

        public init(deleteCount: Int, insert: String) {
            self.deleteCount = deleteCount
            self.insert = insert
        }

        public var isEmpty: Bool { deleteCount == 0 && insert.isEmpty }
    }

    /// The minimal rewrite from `current` to `target`, keeping their common
    /// prefix. iOS gives a keyboard extension no marked-text API, so the
    /// composing region is emulated: every keystroke that only appends a letter
    /// must cost one `insertText` and nothing else, or typing would visibly
    /// erase and re-type the word being written.
    public static func rewrite(from current: String, to target: String) -> Rewrite {
        var shared = 0
        var a = current.startIndex
        var b = target.startIndex
        while a < current.endIndex, b < target.endIndex, current[a] == target[b] {
            shared += 1
            a = current.index(after: a)
            b = target.index(after: b)
        }
        return Rewrite(
            deleteCount: current.count - shared,
            insert: String(target[b...])
        )
    }
}
