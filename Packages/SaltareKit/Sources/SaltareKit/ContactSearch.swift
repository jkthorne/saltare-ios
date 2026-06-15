import Foundation

/// A contact reachable from the universal input.
public struct Contact: Equatable, Sendable {
    public let name: String
    public let number: String
    public init(name: String, number: String) {
        self.name = name
        self.number = number
    }
}

/// Pure name ranking for contacts — word-prefix on any name token, reusing
/// `AppSearch.normalize` so the matching alphabet matches app search. The
/// system store can use a native predicate for efficiency; this is the
/// testable reference (and the in-memory path).
public enum ContactSearch {

    /// Word-prefix matches, capped to `limit`. Blank query → none (contacts
    /// never flood the blank list).
    public static func search(_ contacts: [Contact], query: String, limit: Int = 3) -> [Contact] {
        let q = AppSearch.normalize(query)
        if q.isEmpty { return [] }
        return Array(contacts.filter { matches(normalizedQuery: q, name: $0.name) }.prefix(limit))
    }

    static func matches(normalizedQuery q: String, name: String) -> Bool {
        let n = AppSearch.normalize(name)
        if n == q || n.hasPrefix(q) { return true }
        return n.split(separator: " ").contains { $0.hasPrefix(q) }
    }
}
