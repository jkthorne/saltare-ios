import Foundation

/// What the universal input can resolve to. Row order is one contract,
/// assembled in `AppSearch.search`:
///
///   Calc → ranked AppHits → SettingsLinks (≤2) → Contacts → AgentStub
///
/// Trimmed from the Android `SearchResult`: the work-profile `SectionDivider`
/// and `QuietModeRow` cases are dropped — iOS has no managed-profile analog.
/// Every case is a compile-enforced touch point in the SwiftUI list (render +
/// key + action).
public enum SearchResult: Equatable, Sendable {
    /// Inline arithmetic / unit conversion. `display` is pre-formatted.
    case calc(expression: String, display: String)
    /// A matched launchable entry.
    case appHit(AppEntry)
    /// A deep link into a system / in-app settings screen.
    case settingsLink(SettingsLinkDef)
    /// A contact matched by name; tap targets call or message.
    case contact(name: String, number: String)
    /// Opt-in row shown while Contacts access hasn't been granted.
    case contactsGrant
    /// Offer the query to the agent when search has nothing strong.
    case agentStub(query: String)
}
