import Foundation

/// User intents from the view. `shiftTapped` carries the clock reading (the
/// view supplies it) so the double-tap decision stays pure.
public enum KeyboardEvent: Equatable, Sendable {
    case keyTapped(Character)
    case alternateCommitted(Character)
    case shiftTapped(now: TimeInterval)
    case pageSwitched(LayoutPage)
    /// The user tapped a word in the suggestion strip.
    case suggestionChosen(String)
    case backspaceTapped
    case spaceTapped
    case enterTapped
}
