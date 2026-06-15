import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import SaltareWorkspace

/// Indexes workspace items into CoreSpotlight so they surface in system Spotlight
/// (and the app can deep-link back on tap). The seam is a protocol so the
/// `WorkspaceStore` stays testable / demo-safe (injected `nil` = no indexing).
protocol SpotlightIndexing: Sendable {
    func index(_ entries: [SpotlightEntry])
    func clear()
}

final class SpotlightIndexer: SpotlightIndexing, @unchecked Sendable {
    static let shared = SpotlightIndexer()

    private let index = CSSearchableIndex.default()

    func index(_ entries: [SpotlightEntry]) {
        guard CSSearchableIndex.isIndexingAvailable(), !entries.isEmpty else { return }
        let items = entries.map { entry -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = entry.title
            attributes.contentDescription = entry.contentDescription
            attributes.keywords = entry.keywords
            return CSSearchableItem(
                uniqueIdentifier: entry.identifier,
                domainIdentifier: entry.domainIdentifier,
                attributeSet: attributes
            )
        }
        index.indexSearchableItems(items) // fire-and-forget; failures are non-fatal
    }

    func clear() {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        index.deleteAllSearchableItems()
    }
}
