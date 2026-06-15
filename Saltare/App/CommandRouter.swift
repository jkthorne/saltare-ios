import Foundation
import Observation

/// Cross-entry-point router: App Intents (Siri/Spotlight/Shortcuts) and widget
/// deep links all funnel a pending query here; the command surface observes it.
/// A shared singleton because the entry points can't reach the app's `AppGraph`
/// instance — intents with `openAppWhenRun` run in-process, so this is touched
/// on the main actor only.
@MainActor
@Observable
final class CommandRouter {
    static let shared = CommandRouter()

    /// Non-nil signals a routing request; `""` means "just open to the surface".
    var pendingQuery: String?

    private init() {}

    func route(query: String?) {
        pendingQuery = query ?? ""
    }

    /// Handle `saltare://search?q=…` (and a bare `saltare://search`).
    func handle(_ url: URL) {
        guard url.scheme == "saltare" else { return }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "q" }?.value
        route(query: query)
    }
}
