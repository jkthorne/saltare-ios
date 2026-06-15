import Foundation
import SaltareKit

/// The seam between the UI and the pure `SaltareKit` search engine. A protocol
/// so the command surface can be driven by a fake in previews/tests. The
/// catalog is supplied per call — the model owns installed-filtering and
/// frecency ordering, then hands the ready list here.
protocol SearchProviding: Sendable {
    func results(for query: String, in catalog: [AppEntry]) -> [SearchResult]
}

struct SearchEngine: SearchProviding {
    let links: [SettingsLinkDef]

    init(links: [SettingsLinkDef] = SettingsLinks.all) {
        self.links = links
    }

    func results(for query: String, in catalog: [AppEntry]) -> [SearchResult] {
        AppSearch.search(catalog, query, links: links)
    }
}
