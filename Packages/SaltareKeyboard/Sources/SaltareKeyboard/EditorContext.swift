/// The resolved view of the field being edited: which page to open on, how to
/// seed the shift state, what the return key says, and whether suggestions are
/// allowed at all. Pure policy over `EditorTraits`.
///
/// Unlike the Android port there is no `multiline` here: iOS tells a keyboard
/// extension nothing about whether the field takes more than one line.
public struct EditorContext: Equatable, Sendable {
    public let initialPage: LayoutPage
    public let initialShift: ShiftState
    public let enter: EnterAction
    public let secure: Bool
    public let noSuggestions: Bool

    public init(
        initialPage: LayoutPage,
        initialShift: ShiftState,
        enter: EnterAction,
        secure: Bool,
        noSuggestions: Bool
    ) {
        self.initialPage = initialPage
        self.initialShift = initialShift
        self.enter = enter
        self.secure = secure
        self.noSuggestions = noSuggestions
    }

    public static func resolve(_ traits: EditorTraits) -> EditorContext {
        let numeric = traits.keyboard.isNumeric
        // A password field never gets a dictionary near it, and neither does a
        // URL or an email address — correcting those is how a keyboard breaks a
        // login. An explicit `.no` from the field is obeyed either way.
        let noSuggestions = traits.secure
            || traits.correction == .no
            || traits.keyboard.isStructured
            || numeric

        let autoCaps = traits.capitalization == .sentences || traits.capitalization == .words
        let shift: ShiftState
        if numeric || traits.secure {
            shift = .off
        } else if traits.capitalization == .allCharacters {
            shift = .capsLock
        } else if autoCaps && !traits.hasTextBefore {
            // Only an empty field is seeded: with text already there, the cursor
            // is mid-sentence as often as not.
            shift = .shifted
        } else {
            shift = .off
        }

        return EditorContext(
            initialPage: numeric ? .numeric : .letters,
            initialShift: shift,
            enter: EnterAction(returnKey: traits.returnKey),
            secure: traits.secure,
            noSuggestions: noSuggestions
        )
    }
}
