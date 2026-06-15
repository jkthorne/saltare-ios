import AppIntents

/// Opens the app to the command surface. Surfaces in Spotlight, Siri, and the
/// Shortcuts app via `SaltareShortcuts`.
struct OpenSaltareIntent: AppIntent {
    static let title: LocalizedStringResource = "Open saltare"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        CommandRouter.shared.route(query: nil)
        return .result()
    }
}

/// Opens the app with a pre-filled universal-input query ("Search with saltare
/// for…"). The deterministic engine resolves it on arrival.
struct SearchSaltareIntent: AppIntent {
    static let title: LocalizedStringResource = "Search with saltare"
    static let openAppWhenRun = true

    @Parameter(title: "Query", requestValueDialog: "What should saltare search for?")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult {
        CommandRouter.shared.route(query: query)
        return .result()
    }
}

/// App Shortcuts — the phrases Siri/Spotlight expose without any user setup.
/// `\(.applicationName)` interpolates "saltare".
struct SaltareShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenSaltareIntent(),
            phrases: ["Open \(.applicationName)", "Open \(.applicationName) command"],
            shortTitle: "Open saltare",
            systemImageName: "diamond.fill"
        )
        AppShortcut(
            intent: SearchSaltareIntent(),
            phrases: ["Search with \(.applicationName)", "Ask \(.applicationName)"],
            shortTitle: "Search saltare",
            systemImageName: "magnifyingglass"
        )
    }
}
