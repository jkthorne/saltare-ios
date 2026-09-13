/// What to show in the strip, and what to apply on a word boundary.
/// `autoCorrection` is nil when the typed word should be kept as it is.
public struct SuggestionResult: Equatable, Sendable {
    public let strip: [String]
    public let autoCorrection: String?

    public init(strip: [String], autoCorrection: String?) {
        self.strip = strip
        self.autoCorrection = autoCorrection
    }

    public static let empty = SuggestionResult(strip: [], autoCorrection: nil)
}

/// Turns the in-progress word into strip suggestions plus an autocorrect
/// decision, by blending prefix completions and single-edit corrections ranked
/// by frequency. The casing of every result is matched to what was typed, so
/// `Teh` → `The`, not `the`.
public struct Suggester: Sendable {
    private let dictionary: WordDictionary
    private let corrector: Corrector
    private let limit: Int

    public init(dictionary: WordDictionary, corrector: Corrector, limit: Int = 3) {
        self.dictionary = dictionary
        self.corrector = corrector
        self.limit = limit
    }

    public init(dictionary: WordDictionary, limit: Int = 3) {
        self.init(dictionary: dictionary, corrector: Corrector(dictionary: dictionary), limit: limit)
    }

    public func suggest(_ typed: String) -> SuggestionResult {
        guard !typed.isEmpty else { return .empty }
        let lower = typed.lowercased()
        let isWord = dictionary.contains(lower)

        let completions = dictionary.words(withPrefix: lower, limit: limit * 2)
        let corrections = corrector.candidates(lower)

        // Only a token that is not itself a word gets corrected out from under
        // the user.
        let correction = isWord ? nil : corrections.first

        var ordered: [String] = []
        var seen = Set<String>()
        func offer(_ word: String) {
            guard seen.insert(word).inserted else { return }
            ordered.append(word)
        }
        if let correction { offer(correction) }
        offer(lower) // the literal typing is always offered, so autocorrect can be refused
        for word in (completions + corrections).sorted(by: byFrequency) {
            offer(word)
        }

        return SuggestionResult(
            strip: ordered.prefix(limit).map { Suggester.matchCase($0, like: typed) },
            autoCorrection: correction.map { Suggester.matchCase($0, like: typed) }
        )
    }

    private func byFrequency(_ left: String, _ right: String) -> Bool {
        let (l, r) = (dictionary.frequency(of: left), dictionary.frequency(of: right))
        return l == r ? left < right : l > r
    }

    /// Reapplies `like`'s capitalization pattern (ALL CAPS / Title / lower).
    static func matchCase(_ word: String, like: String) -> String {
        let letters = like.filter { $0.isLetter }
        if like.count > 1, !letters.isEmpty, letters.allSatisfy({ $0.isUppercase }) {
            return word.uppercased()
        }
        if like.first?.isUppercase == true {
            return word.prefix(1).uppercased() + word.dropFirst()
        }
        return word
    }
}
