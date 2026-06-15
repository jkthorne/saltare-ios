import Foundation
import Observation
import SaltareKit

/// The command surface's view model. Deterministic and synchronous for now —
/// the search engine is pure and fast, so there's no debounce yet (it arrives
/// with the async Contacts query in iP1.2). Touched only from the UI.
@Observable
final class CommandSurfaceModel {
    private(set) var query: String = ""
    private(set) var results: [SearchResult] = []

    private let search: SearchProviding

    init(search: SearchProviding) {
        self.search = search
        results = search.results(for: "")
    }

    func setQuery(_ newValue: String) {
        query = newValue
        results = search.results(for: newValue)
    }
}
