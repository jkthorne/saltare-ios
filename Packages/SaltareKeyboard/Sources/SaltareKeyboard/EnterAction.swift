/// What the return key claims it will do, derived from the field's return-key
/// type. The label echoes the command surface's HUD voice (`SEARCH // ASK`).
///
/// It is only ever a *label* on iOS: a keyboard extension has no way to invoke
/// an editor action the way Android's `performDefaultEditorAction` does, so
/// every one of these commits a newline and the host app's text-field delegate
/// decides what that means (`EditorIntent.performEnter`).
public enum EnterAction: Equatable, Sendable, CaseIterable {
    case go
    case search
    case send
    case done
    case next
    case previous
    case none

    public var label: String {
        switch self {
        case .go: "GO"
        case .search: "SEARCH"
        case .send: "SEND"
        case .done: "DONE"
        case .next: "NEXT"
        case .previous: "PREV"
        case .none: "ENTER"
        }
    }

    /// Maps a field's return-key type. `UIReturnKeyType` has no "previous", so
    /// that case only arrives from tests and future non-UIKit hosts.
    public init(returnKey: ReturnKey) {
        switch returnKey {
        case .go, .join, .route: self = .go
        case .search, .google, .yahoo: self = .search
        case .send: self = .send
        case .done, .emergencyCall: self = .done
        case .next, .continue: self = .next
        case .default: self = .none
        }
    }
}
