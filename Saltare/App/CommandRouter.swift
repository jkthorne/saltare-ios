import Foundation
import Observation
import CoreSpotlight

/// Cross-entry-point router: App Intents (Siri/Spotlight/Shortcuts), widget deep
/// links, and Spotlight result taps all funnel here; the command surface observes
/// it. A shared singleton because the entry points can't reach the app's
/// `AppGraph` instance — intents with `openAppWhenRun` run in-process, so this is
/// touched on the main actor only.
@MainActor
@Observable
final class CommandRouter {
    static let shared = CommandRouter()

    /// Non-nil signals a routing request; `""` means "just open to the surface".
    var pendingQuery: String?
    /// Non-nil signals a request to present an in-app destination (deep links).
    var pendingRoute: CommandRoute?

    private init() {}

    func route(query: String?) {
        pendingQuery = query ?? ""
    }

    /// Handle a `saltare://` deep link — `search?q=…` (the query surface),
    /// `task/<slug>` / `document/<slug>` (Spotlight items → the workspace browser
    /// on the right tab), and `workspace` / `agent` / `signin`.
    func handle(_ url: URL) {
        guard url.scheme == "saltare" else { return }
        switch url.host {
        case "search":
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "q" }?.value
            route(query: query)
        case "task": pendingRoute = .workspace(tab: .tasks)
        case "document": pendingRoute = .workspace(tab: .documents)
        case "workspace": pendingRoute = .workspace()
        case "agent": pendingRoute = .agent(query: "")
        case "signin": pendingRoute = .signIn
        default: break
        }
    }

    /// A tapped Spotlight result — its unique identifier is the item's
    /// `saltare://…` deep link.
    func handleSpotlight(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let url = URL(string: identifier) else { return }
        handle(url)
    }
}
