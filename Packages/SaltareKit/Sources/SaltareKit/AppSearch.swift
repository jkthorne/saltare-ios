import Foundation

/// Pure search over the (already sorted, filtered, renamed) entry list. Ported
/// 1:1 from the Android `:launcher` `AppSearch`, minus the work-profile section
/// (no iOS analog).
public enum AppSearch {

    // MARK: - Normalization

    /// Lowercase, strip diacritics, drop punctuation — the matching alphabet.
    /// Punctuation is removed (not spaced): "F-Droid" → "fdroid".
    public static func normalize(_ s: String) -> String {
        var out = ""
        for scalar in s.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars {
            if scalar.properties.generalCategory == .nonspacingMark { continue } // strip diacritics
            let c = Character(scalar)
            if c.isASCIILetterOrDigit || c == " " { out.append(c) }
        }
        return out.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }

    /// Like `normalize` but punctuation becomes a word break:
    /// "F-Droid" → ["f", "droid"].
    private static func tokens(_ s: String) -> [String] {
        var spaced = ""
        for scalar in s.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars {
            if scalar.properties.generalCategory == .nonspacingMark { continue }
            let c = Character(scalar)
            spaced.append(c.isASCIILetterOrDigit ? c : " ")
        }
        return normalize(spaced).split(separator: " ").map(String.init).filter { !$0.isEmpty }
    }

    // MARK: - Ranking

    private static let rankExact = 0
    private static let rankWordPrefix = 1
    private static let rankSubstring = 2
    private static let rankSubsequence = 3

    /// How many settings-link rows a query may surface.
    private static let maxLinkRows = 2

    /// Match quality, or nil for a miss. Subsequence needs ≥3 chars or it floods.
    private static func rank(qJoined: String, qSpaced: String, label: String) -> Int? {
        let labelTokens = tokens(label)
        let labelJoined = labelTokens.joined()
        let labelSpaced = labelTokens.joined(separator: " ")
        if labelJoined == qJoined { return rankExact }
        if labelTokens.contains(where: { $0.hasPrefix(qJoined) }) ||
            labelJoined.hasPrefix(qJoined) ||
            labelSpaced.hasPrefix(qSpaced) { return rankWordPrefix }
        if !qJoined.isEmpty && labelJoined.contains(qJoined) { return rankSubstring }
        if qJoined.count >= 3 && isSubsequence(qJoined, labelJoined) { return rankSubsequence }
        return nil
    }

    private static func isSubsequence(_ needle: String, _ haystack: String) -> Bool {
        var it = needle.startIndex
        for c in haystack {
            if c == needle[it] { it = needle.index(after: it) }
            if it == needle.endIndex { return true }
        }
        return false
    }

    // MARK: - Assembly

    /// The universal input's one assembly contract. Blank query → every entry
    /// in input order. Otherwise:
    ///
    ///   Calc (if the query is math/conversion)
    ///   → app hits ranked exact > word-prefix > substring > subsequence (≥3),
    ///     stable within rank (input order — callers pass sorted lists)
    ///   → settings links (≤2, strictly below app hits)
    ///   → AgentStub, only when nothing strong matched (no calc, no link, no
    ///     exact/word-prefix app) — "Go" must never ambush muscle memory.
    public static func search(
        _ apps: [AppEntry],
        _ query: String,
        links: [SettingsLinkDef] = []
    ) -> [SearchResult] {
        let qSpaced = normalize(query)
        if qSpaced.isEmpty { return apps.map { .appHit($0) } }
        let qJoined = qSpaced.replacingOccurrences(of: " ", with: "")

        var results: [SearchResult] = []

        // The evaluator sees the RAW query: normalize strips the operators.
        if let calc = Calculator.evaluate(query) ?? UnitConvert.convert(query) {
            results.append(.calc(expression: query.trimmingCharacters(in: .whitespaces), display: calc))
        }

        // Stable sort by rank: equal ranks keep input order.
        let ranked = apps.enumerated()
            .compactMap { idx, app -> (rank: Int, idx: Int, app: AppEntry)? in
                rank(qJoined: qJoined, qSpaced: qSpaced, label: app.displayLabel).map { ($0, idx, app) }
            }
            .sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.idx < $1.idx }
        results.append(contentsOf: ranked.map { .appHit($0.app) })

        let linkHits = links.filter { link in
            ([link.label] + link.keywords).contains { term in
                if let r = rank(qJoined: qJoined, qSpaced: qSpaced, label: term) { return r <= rankWordPrefix }
                return false
            }
        }.prefix(maxLinkRows)
        results.append(contentsOf: linkHits.map { .settingsLink($0) })

        let topRank = ranked.first?.rank ?? Int.max
        let strongHit = (results.contains { if case .calc = $0 { return true }; return false }) ||
            !linkHits.isEmpty ||
            topRank <= rankWordPrefix
        if !strongHit { results.append(.agentStub(query: query)) }

        return results
    }

    /// Contact rows arrive async (a debounced Contacts query) — splice them into
    /// an already-assembled list, before the AgentStub so the escape hatch
    /// stays last.
    public static func withContacts(_ results: [SearchResult], _ contacts: [SearchResult]) -> [SearchResult] {
        if contacts.isEmpty { return results }
        guard let stubIndex = results.firstIndex(where: { if case .agentStub = $0 { return true }; return false }) else {
            return results + contacts
        }
        return Array(results[..<stubIndex]) + contacts + Array(results[stubIndex...])
    }

    /// The entry to auto-launch as the user types, or nil. Guard rails: the
    /// toggle is on, the query is ≥2 chars and grew (typing forward — never on
    /// deletion), exactly one hit remains, and that hit is a true word-prefix
    /// match (a unique substring or subsequence shouldn't fire).
    public static func autoLaunchCandidate(
        previousQuery: String,
        query: String,
        results: [SearchResult],
        enabled: Bool
    ) -> AppEntry? {
        guard enabled else { return nil }
        guard query.count >= 2, query.count > previousQuery.count else { return nil }
        guard results.count == 1, case let .appHit(app) = results[0] else { return nil }
        let qSpaced = normalize(query)
        let qJoined = qSpaced.replacingOccurrences(of: " ", with: "")
        if let r = rank(qJoined: qJoined, qSpaced: qSpaced, label: app.displayLabel), r <= rankWordPrefix {
            return app
        }
        return nil
    }
}

private extension Character {
    var isASCIILetterOrDigit: Bool {
        (self >= "a" && self <= "z") || (self >= "0" && self <= "9")
    }
}
