/// A single key in a layout. Pure data — the view maps each case to a cell and
/// an event. `weight` is the horizontal share within its row (letters are 1).
///
/// Keycaps always render uppercase (the locked design decision); the associated
/// character is the *base* one and the reducer decides the committed case from
/// the shift state.
public enum Key: Equatable, Sendable {
    /// `alternates` are committed verbatim on long-press (e.g. `q` → `1`).
    case character(Character, alternates: String)
    case page(LayoutPage, label: String)
    case shift
    case backspace
    case space
    case enter
    /// Switch to the next installed keyboard. No Android counterpart: iOS
    /// requires a way out of a third-party keyboard, and only offers it as a
    /// key we draw ourselves.
    case globe

    /// Enum cases cannot carry default arguments; this is the common spelling.
    public static func char(_ character: Character, alternates: String = "") -> Key {
        .character(character, alternates: alternates)
    }

    public var weight: Double {
        switch self {
        case .character: 1
        case .space: 4
        case .page, .shift, .backspace, .enter, .globe: 1.5
        }
    }

    /// The base character a `.character` key types, if it is one.
    public var character: Character? {
        if case let .character(c, _) = self { return c }
        return nil
    }

    /// The character a long-press commits, if the key has one.
    public var alternate: Character? {
        if case let .character(_, alternates) = self { return alternates.first }
        return nil
    }
}
