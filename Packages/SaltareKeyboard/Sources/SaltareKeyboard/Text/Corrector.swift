/// Norvig-style single-edit correction, with substitutions restricted to
/// physically adjacent keys (`KeyProximity`) so corrections favour real
/// fat-finger typos and the candidate set stays small.
public struct Corrector: Sendable {
    private let dictionary: WordDictionary

    public init(dictionary: WordDictionary) {
        self.dictionary = dictionary
    }

    /// Dictionary words one edit away from `word`, most frequent first. Ties
    /// break alphabetically: the candidate set is a `Set`, so without a total
    /// order the strip would shuffle between identical keystrokes.
    public func candidates(_ word: String) -> [String] {
        edits(word)
            .filter { $0 != word && dictionary.contains($0) }
            .sorted { left, right in
                let (l, r) = (dictionary.frequency(of: left), dictionary.frequency(of: right))
                return l == r ? left < right : l > r
            }
    }

    private static let alphabet = Array("abcdefghijklmnopqrstuvwxyz")

    private func edits(_ word: String) -> Set<String> {
        let characters = Array(word)
        let n = characters.count
        var out = Set<String>()
        for i in 0..<n {
            // delete
            var deleted = characters
            deleted.remove(at: i)
            out.insert(String(deleted))
            // transpose with the next character
            if i < n - 1 {
                var transposed = characters
                transposed.swapAt(i, i + 1)
                out.insert(String(transposed))
            }
            // replace with an adjacent key
            for neighbor in KeyProximity.neighbors(of: characters[i]) {
                var replaced = characters
                replaced[i] = neighbor
                out.insert(String(replaced))
            }
        }
        // insert any letter
        for i in 0...n {
            for letter in Corrector.alphabet {
                var inserted = characters
                inserted.insert(letter, at: i)
                out.insert(String(inserted))
            }
        }
        return out
    }
}
