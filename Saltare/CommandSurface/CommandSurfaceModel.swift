import Foundation
import Observation
import UIKit
import SaltareKit

/// The command surface's view model. Owns catalog assembly (installed-filtering
/// + frecency ordering), the deterministic search, the debounced Contacts
/// splice, and action dispatch. `@MainActor` because selection touches UIKit
/// (launch / pasteboard).
@MainActor
@Observable
final class CommandSurfaceModel {
    private(set) var query: String = ""
    private(set) var results: [SearchResult] = []
    /// Transient bottom toast — copy confirmations and the iP2 agent placeholder.
    private(set) var toast: String?

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
        switch result {
        case let .calc(_, display):
            graph.pasteboard.copy(display)
            showToast("Copied  \(display)")

        case let .appHit(app):
            recording.launch(app) // the choke point records frecency
            availableCatalog = Self.ordered(availableCatalog, graph: graph)
            if query.isEmpty { recompute() }

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

        case .agentStub:
            // iP2 routes this to the on-device agent.
            showToast("Agent arrives in iP2")
        }
    }

    private func openSettings(_ target: SettingsTarget) {
        switch target {
        case .appSettings:
            graph.launcher.launch(UIApplication.openSettingsURLString)
        case .appNotificationSettings:
            graph.launcher.launch(UIApplication.openNotificationSettingsURLString)
        case .internalRoute:
            // In-app navigation lands with the workspace surfaces (iP3).
            showToast("Coming soon")
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
