import Foundation

/// Loads the bundled `dictionary.txt` (`word frequency` per line, frequency
/// ordered) into a `WordDictionary`.
///
/// Source: hermitdave/FrequencyWords (MIT), derived from the OpenSubtitles
/// corpus, filtered to lowercase alphabetic words — the same asset the Android
/// keyboard ships. See NOTICE.
///
/// The roadmap called for an mmap'd trie against the extension's ~60 MB ceiling.
/// The list is 377 KB of text and parses into a few MB of `String`s, which is
/// well inside that, so this stays a plain in-memory index until a memory report
/// from a device says otherwise. Parse it off the main thread regardless: it is
/// 30k lines.
public enum WordList {

    /// The word list shipped inside this package's bundle, or nil if it is
    /// missing — the keyboard still types, it just stops suggesting.
    public static func bundled(named name: String = "dictionary") -> WordDictionary? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return nil
        }
        return parse(text)
    }

    /// `word frequency` per line; anything else on a line is skipped rather than
    /// failing the load.
    public static func parse(_ text: String) -> WordDictionary {
        var entries: [WordDictionary.Entry] = []
        entries.reserveCapacity(32_000)
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let space = line.firstIndex(of: " ") else { continue }
            let word = line[line.startIndex..<space]
            guard !word.isEmpty,
                  let frequency = Int(line[line.index(after: space)...].trimmingCharacters(in: .whitespacesAndNewlines))
            else { continue }
            entries.append(WordDictionary.Entry(word: String(word), frequency: frequency))
        }
        return WordDictionary(entries: entries)
    }
}
