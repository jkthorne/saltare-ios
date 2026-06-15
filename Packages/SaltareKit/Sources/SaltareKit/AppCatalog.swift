import Foundation

/// The curated launch catalog. iOS can't enumerate installed apps, so "app
/// hits" come from two sources:
///
///  1. **External apps** by URL scheme — the app target probes these with
///     `canOpenURL` (each scheme must be declared in `LSApplicationQueriesSchemes`,
///     ≤50) and hides the ones that aren't installed. The list is curated, not
///     exhaustive — surfaces what's missing rather than pretending coverage.
///  2. **saltare destinations** — the workspace's own surfaces (channels,
///     agents, tasks…) as `saltare://…` internal routes, populated in iP3 once
///     the API client lands.
///
/// Kept here so search has a real target list to rank against; the app target
/// owns installed-filtering and launch resolution.
public enum AppCatalog {

    /// A starter set of common third-party apps and their URL schemes.
    public static let externalApps: [AppEntry] = [
        AppEntry(id: "music.apple", label: "Music", launchURL: "music://"),
        AppEntry(id: "maps.apple", label: "Maps", launchURL: "maps://"),
        AppEntry(id: "spotify", label: "Spotify", launchURL: "spotify://"),
        AppEntry(id: "youtube", label: "YouTube", launchURL: "youtube://"),
        AppEntry(id: "whatsapp", label: "WhatsApp", launchURL: "whatsapp://"),
        AppEntry(id: "slack", label: "Slack", launchURL: "slack://"),
        AppEntry(id: "github", label: "GitHub", launchURL: "github://"),
        AppEntry(id: "gmail", label: "Gmail", launchURL: "googlegmail://"),
        AppEntry(id: "telegram", label: "Telegram", launchURL: "tg://"),
        AppEntry(id: "things", label: "Things", launchURL: "things://"),
    ]

    /// Built-in destinations reachable from the universal input without any
    /// external app. Always present.
    public static let builtins: [AppEntry] = [
        AppEntry(id: "saltare.agent", label: "Ask the Agent", launchURL: "saltare://agent"),
        AppEntry(id: "saltare.signin", label: "Sign in to saltare", launchURL: "saltare://signin"),
        AppEntry(id: "saltare.settings", label: "Settings", launchURL: "saltare://settings"),
    ]
}
