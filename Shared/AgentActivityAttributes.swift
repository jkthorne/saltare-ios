import ActivityKit

/// The Live Activity for a running agent turn. Compiled into BOTH the app (which
/// requests/updates/ends the activity) and the widget extension (which renders
/// the Lock Screen + Dynamic Island) — the documented ActivityKit sharing
/// pattern, matched by type name. Plain strings/ints so the widget needs no
/// SaltareAgent dependency; the app fills them via `AgentActivityPresentation`.
struct AgentActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var statusLabel: String
        var detail: String
        var toolCount: Int
        var isActive: Bool
    }

    /// Static (set at request time) — the surface title.
    var title: String
}
