import Foundation

/// The immutable domain state. `lastShiftTapAt` is fed by the view (never read
/// from a clock in here) so the double-tap caps-lock decision stays pure.
///
/// `composing` is the in-progress word; `autoCorrection` is what replaces it at
/// a word boundary (kept in sync by the model from the dictionary);
/// `fieldSuggestable` is whether the field allows suggestions at all.
public struct KeyboardState: Equatable, Sendable {
    public var page: LayoutPage
    public var shift: ShiftState
    public var enter: EnterAction
    public var lastShiftTapAt: TimeInterval?
    public var composing: String
    public var autoCorrection: String?
    public var fieldSuggestable: Bool

    public init(
        page: LayoutPage = .letters,
        shift: ShiftState = .off,
        enter: EnterAction = .none,
        lastShiftTapAt: TimeInterval? = nil,
        composing: String = "",
        autoCorrection: String? = nil,
        fieldSuggestable: Bool = false
    ) {
        self.page = page
        self.shift = shift
        self.enter = enter
        self.lastShiftTapAt = lastShiftTapAt
        self.composing = composing
        self.autoCorrection = autoCorrection
        self.fieldSuggestable = fieldSuggestable
    }

    /// A field the editor context allows suggestions in, while the letters page
    /// is showing.
    public var suggestionsActive: Bool { fieldSuggestable && page == .letters }

    /// The state a new input session starts in.
    public init(context: EditorContext) {
        self.init(
            page: context.initialPage,
            shift: context.initialShift,
            enter: context.enter,
            fieldSuggestable: !context.noSuggestions
        )
    }
}
