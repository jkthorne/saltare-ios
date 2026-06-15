import Foundation
import SaltareKit
import SaltareAgent

/// `LauncherCapabilities` backed by the command surface's catalog — the agent's
/// `open_app` tool resolves names through the same `AppSearch` ranking the user
/// types into, then launches via the installed-filtered `AppLaunching`.
struct CommandSurfaceCapabilities: LauncherCapabilities {
    let catalog: [AppEntry]
    let launcher: AppLaunching

    func appLabels() -> [String] { catalog.map(\.displayLabel) }

    func openApp(_ query: String) async -> OpenAppResult {
        let hits = AppSearch.search(catalog, query).compactMap { result -> AppEntry? in
            if case let .appHit(app) = result { return app }
            return nil
        }
        guard let best = hits.first else { return .notFound(query) }

        let launched = await MainActor.run { () -> Bool in
            guard let url = best.launchURL else { return true } // internal destination
            if url.hasPrefix("saltare://") { return true }       // in-app route
            guard launcher.canLaunch(url) else { return false }
            launcher.launch(url)
            return true
        }
        return launched ? .launched(best.displayLabel) : .notFound(query)
    }
}
