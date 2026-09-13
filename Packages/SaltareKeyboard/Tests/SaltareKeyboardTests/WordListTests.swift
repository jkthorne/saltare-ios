import XCTest
@testable import SaltareKeyboard

/// Covers the shipped asset itself: the resource wiring, the parse, and the
/// prefix index. If the word list ever stops being bundled with the package,
/// this is what says so — the keyboard would otherwise just quietly stop
/// suggesting.
final class WordListTests: XCTestCase {

    func testTheBundledWordListLoads() throws {
        let dictionary = try XCTUnwrap(WordList.bundled(), "dictionary.txt is not in the package bundle")
        XCTAssertEqual(dictionary.count, 30_000)
        XCTAssertTrue(dictionary.contains("the"))
        XCTAssertGreaterThan(dictionary.frequency(of: "the"), dictionary.frequency(of: "keyboard"))
    }

    func testMalformedLinesAreSkippedRatherThanFailingTheLoad() {
        let dictionary = WordList.parse("""
        the 1000
        broken
        also broken
        work 200

        """)
        XCTAssertEqual(dictionary.count, 2)
        XCTAssertTrue(dictionary.contains("the"))
        XCTAssertTrue(dictionary.contains("work"))
    }

    func testPrefixLookupIsRankedAndBounded() {
        let dictionary = WordList.parse("""
        a 100
        ab 90
        abc 80
        abcd 70
        b 60
        """)
        XCTAssertEqual(dictionary.words(withPrefix: "ab", limit: 2), ["ab", "abc"])
        XCTAssertEqual(dictionary.words(withPrefix: "a", limit: 10), ["a", "ab", "abc", "abcd"])
        XCTAssertEqual(dictionary.words(withPrefix: "z", limit: 3), [])
        XCTAssertEqual(dictionary.words(withPrefix: "", limit: 3), [])
    }

    func testARealPrefixLookupBeatsTheStripSize() throws {
        let dictionary = try XCTUnwrap(WordList.bundled())
        let completions = dictionary.words(withPrefix: "th", limit: 3)
        XCTAssertEqual(completions.count, 3)
        XCTAssertEqual(completions.first, "the", "the most frequent th- word leads")
        XCTAssertTrue(completions.allSatisfy { $0.hasPrefix("th") })
    }
}
