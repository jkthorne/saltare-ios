import Foundation

/// Where a settings-link row points. iOS — unlike Android's rich
/// `android.settings.*` catalog — only exposes a few *public* deep links;
/// `App-Prefs:` URLs are private API and get apps rejected. So most rows open
/// our own app's settings pane or an in-app destination.
public enum SettingsTarget: Equatable, Sendable {
    /// `UIApplication.openSettingsURLString` — this app's page in Settings
    /// (where the user grants Contacts/Location/Notifications/etc.).
    case appSettings
    /// `UIApplication.openNotificationSettingsURLString` (iOS 16+).
    case appNotificationSettings
    /// An in-app saltare route (e.g. `saltare://settings/agent`).
    case internalRoute(String)
}

/// A settings screen reachable from the universal input. The data layer
/// resolves [target] to a URL and opens it; the domain stays platform-free.
public struct SettingsLinkDef: Equatable, Sendable {
    public let id: String
    public let label: String
    public let target: SettingsTarget
    public let keywords: [String]

    public init(id: String, label: String, target: SettingsTarget, keywords: [String]) {
        self.id = id
        self.label = label
        self.target = target
        self.keywords = keywords
    }
}

/// The curated iOS catalog. Honest and small (see the note on `SettingsTarget`):
/// it routes mostly to this app's own Settings pane and in-app destinations.
public enum SettingsLinks {
    public static let all: [SettingsLinkDef] = [
        SettingsLinkDef(id: "settings", label: "App Settings", target: .appSettings,
                        keywords: ["settings", "permissions", "privacy", "system"]),
        SettingsLinkDef(id: "notifications", label: "Notifications", target: .appNotificationSettings,
                        keywords: ["notifications", "alerts", "push", "badges"]),
        SettingsLinkDef(id: "contacts", label: "Contacts Access", target: .appSettings,
                        keywords: ["contacts", "permission", "allow"]),
        SettingsLinkDef(id: "location", label: "Location Access", target: .appSettings,
                        keywords: ["location", "gps", "permission"]),
        SettingsLinkDef(id: "agent", label: "Agent Settings", target: .internalRoute("saltare://settings/agent"),
                        keywords: ["agent", "claude", "model", "api key"]),
        SettingsLinkDef(id: "theme", label: "Theme", target: .internalRoute("saltare://settings/theme"),
                        keywords: ["theme", "dark", "light", "parchment", "appearance"]),
    ]
}
