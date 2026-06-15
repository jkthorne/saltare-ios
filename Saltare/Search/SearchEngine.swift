import Foundation
import SaltareKit

/// The seam between the UI and the pure `SaltareKit` search engine. A protocol
/// so the command surface can be driven by a fake in previews/tests.
protocol SearchProviding: Sendable {
    func results(for query: String) -> [SearchResult]
}

/// Assembles the launch catalog and runs the universal-input contract.
///
/// iP1.0 wires the deterministic core: `AppSearch.search` over the curated
/// catalog + the iOS settings/permission links. Later milestones add the
/// installed-app filtering (`canOpenURL`), Contacts splicing, frecency
/// ordering, and the launch choke point.
struct SearchEngine: SearchProviding {
    let catalog: [AppEntry]
    let links: [SettingsLinkDef]

    init(
        catalog: [AppEntry] = AppCatalog.builtins + AppCatalog.externalApps,
        links: [SettingsLinkDef] = SettingsLinks.all
    ) {
        self.catalog = catalog
        self.links = links
    }

    func results(for query: String) -> [SearchResult] {
        AppSearch.search(catalog, query, links: links)
    }
}
