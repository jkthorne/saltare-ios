import Foundation
import Observation
import UIKit
import SaltareKit

/// In-app destinations the command surface presents as sheets.
enum CommandRoute: Identifiable, Equatable {
    case agent(query: String)
    case agentSettings
    case signIn

    var id: String {
        switch self {
        case let .agent(query): "agent:\(query)"
        case .agentSettings: "agentSettings"
        case .signIn: "signIn"
        }
    }
}

/// The command surface's view model. Owns catalog assembly (installed-filtering
/// + frecency ordering), the deterministic search, the debounced Contacts
/// splice, and action dispatch. `@MainActor` because selection touches UIKit
/// (launch / pasteboard).
@MainActor
@Observable
final class CommandSurfaceModel {
    private(set) var query: String = ""
    private(set) var results: [SearchResult] = []
    /// Transient bottom toast — copy confirmations.
    private(set) var toast: String?
    /// The presented sheet (agent / agent settings); the view binds to it.
    var presentedRoute: CommandRoute?

    private let graph: AppGraph
    private let recording: RecordingLauncher
    private var availableCatalog: [AppEntry]
    private var contactRows: [SearchResult] = []
    private var contactsTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    init(graph: AppGraph) {
        self.graph = graph
        self.recording = RecordingLauncher(launcher: graph.launcher, frecency: graph.frecency)
        // Installed-filter: builtins always; externals gated by canLaunch.
        let installed = graph.catalog.filter { entry in
            guard let url = entry.launchURL else { return true }
            return url.hasPrefix("saltare://") || graph.launcher.canLaunch(url)
        }
        self.availableCatalog = Self.ordered(installed, graph: graph)
        self.results = graph.search.results(for: "", in: availableCatalog)
    }

    private static func ordered(_ catalog: [AppEntry], graph: AppGraph) -> [AppEntry] {
        Frecency.order(catalog, stats: graph.frecency.stats(), nowMs: graph.clock.nowMs)
    }

    func setQuery(_ newValue: String) {
        query = newValue
        recompute()
        scheduleContacts(for: newValue)
    }

    /// Re-runs the deterministic engine and splices the current contact rows.
    private func recompute() {
        let base = graph.search.results(for: query, in: availableCatalog)
        results = AppSearch.withContacts(base, contactRows)
    }

    // MARK: - Contacts (debounced splice)

    private func scheduleContacts(for query: String) {
        contactsTask?.cancel()
        // Contacts are names — skip pure calc/number queries (e.g. "2+3").
        let normalized = AppSearch.normalize(query)
        guard normalized.contains(where: { $0.isLetter }) else {
            contactRows = []
            recompute()
            return
        }
        switch graph.contacts.authorization {
        case .denied:
            contactRows = []
            recompute()
        case .notDetermined:
            // Offer the opt-in row (spliced before the agent stub).
            contactRows = [.contactsGrant]
            recompute()
        case .authorized:
            contactsTask = Task {
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
                let matched = await graph.contacts.search(query)
                if Task.isCancelled { return }
                contactRows = matched.map { .contact(name: $0.name, number: $0.number) }
                recompute()
            }
        }
    }

    // MARK: - Selection

    func select(_ result: SearchResult) {
        Haptics.tap()
        switch result {
        case let .calc(_, display):
            graph.pasteboard.copy(display)
            showToast("Copied  \(display)")

        case let .appHit(app):
            if let route = Self.internalRoute(app.launchURL) {
                presentedRoute = route // builtin saltare:// destinations
            } else {
                recording.launch(app) // the choke point records frecency
                availableCatalog = Self.ordered(availableCatalog, graph: graph)
                if query.isEmpty { recompute() }
            }

        case let .settingsLink(def):
            openSettings(def.target)

        case let .contact(_, number):
            let digits = number.filter { !$0.isWhitespace }
            graph.launcher.launch("tel:\(digits)")

        case .contactsGrant:
            Task {
                _ = await graph.contacts.requestAccess()
                scheduleContacts(for: query)
            }

        case let .agentStub(query):
            presentedRoute = .agent(query: query)
        }
    }

    private func openSettings(_ target: SettingsTarget) {
        switch target {
        case .appSettings:
            graph.launcher.launch(UIApplication.openSettingsURLString)
        case .appNotificationSettings:
            graph.launcher.launch(UIApplication.openNotificationSettingsURLString)
        case let .internalRoute(route):
            if let route = Self.internalRoute(route) {
                presentedRoute = route
            } else {
                showToast("Coming soon") // e.g. theme — lands later
            }
        }
    }

    /// Maps a `saltare://` URL to its in-app sheet, or nil if it's not one.
    private static func internalRoute(_ url: String?) -> CommandRoute? {
        switch url {
        case "saltare://agent": .agent(query: "")
        case "saltare://signin": .signIn
        case "saltare://settings", "saltare://settings/agent": .agentSettings
        default: nil
        }
    }

    private func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.4))
            if !Task.isCancelled { toast = nil }
        }
    }
}
