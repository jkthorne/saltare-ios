import Foundation

/// What launching an app resolved to, human-readable for the tool result.
public enum OpenAppResult: Sendable, Equatable {
    case launched(String)
    case notFound(String)
    case ambiguous([String])
}

/// Host-launcher capabilities the agent's `open_app` tool uses, defined here so
/// the agent never depends on the app's command-surface types directly (the
/// Android `LauncherCapabilities` seam). The iOS impl resolves to the curated
/// catalog + `canOpenURL`.
public protocol LauncherCapabilities: Sendable {
    /// Display labels of launchable entries, for the `open_app` description.
    func appLabels() -> [String]
    /// Launch the best match for `query`; returns what happened.
    func openApp(_ query: String) async -> OpenAppResult
}
