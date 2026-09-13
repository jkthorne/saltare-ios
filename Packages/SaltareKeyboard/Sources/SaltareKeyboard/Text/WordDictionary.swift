/// A frequency-ranked word list. Pure — built from `(word, frequency)` entries
/// (the bundled asset on device, a fixture in tests). Words are assumed
/// lowercase; casing is reapplied by `Suggester` to match what was typed.
///
/// Prefix lookup binary-searches an alphabetical index rather than scanning the
/// whole list like the Android port does: this runs on every keystroke inside a
/// keyboard extension, which iOS gives far less room than an app.
public struct WordDictionary: Sendable {

    public struct Entry: Equatable, Sendable {
        public let word: String
        public let frequency: Int

        public init(word: String, frequency: Int) {
            self.word = word
            self.frequency = frequency
        }
    }

    private let frequencyByWord: [String: Int]
    private let sorted: [String]

    public init(entries: [Entry]) {
        var frequencies = [String: Int](minimumCapacity: entries.count)
        // First writer wins, so a duplicated word keeps its highest-ranked
        // frequency when the caller passes the list in frequency order.
        for entry in entries where frequencies[entry.word] == nil {
            frequencies[entry.word] = entry.frequency
        }
        self.frequencyByWord = frequencies
        self.sorted = frequencies.keys.sorted()
    }

    public var count: Int { frequencyByWord.count }

    public func contains(_ word: String) -> Bool { frequencyByWord[word] != nil }

    public func frequency(of word: String) -> Int { frequencyByWord[word] ?? 0 }

    /// The `limit` most frequent words starting with `prefix` (the prefix itself
    /// included when it is a word), most frequent first.
    public func words(withPrefix prefix: String, limit: Int) -> [String] {
        guard !prefix.isEmpty, limit > 0 else { return [] }
        var best: [String] = []
        var index = lowerBound(prefix)
        while index < sorted.count, sorted[index].hasPrefix(prefix) {
            insertRanked(sorted[index], into: &best, limit: limit)
            index += 1
        }
        return best
    }

    /// The first position in `sorted` whose word is not ordered before `prefix`
    /// — the start of the prefix's contiguous run.
    private func lowerBound(_ prefix: String) -> Int {
        var low = 0
        var high = sorted.count
        while low < high {
            let mid = (low + high) / 2
            if sorted[mid] < prefix {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    /// Keeps `best` as the top-`limit` by frequency. A bounded insertion beats
    /// sorting the whole run: a one-letter prefix matches thousands of words and
    /// the strip shows three.
    private func insertRanked(_ word: String, into best: inout [String], limit: Int) {
        let score = frequency(of: word)
        if best.count == limit, score <= frequency(of: best[best.count - 1]) { return }
        var position = best.count
        while position > 0, frequency(of: best[position - 1]) < score {
            position -= 1
        }
        best.insert(word, at: position)
        if best.count > limit { best.removeLast() }
    }
}
