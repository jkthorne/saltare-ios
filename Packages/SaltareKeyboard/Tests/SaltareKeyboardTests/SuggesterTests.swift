import XCTest
@testable import SaltareKeyboard

/// Ported from the Android `SuggesterTest`, driven by a fixture dictionary.
final class SuggesterTests: XCTestCase {

    private let suggester = Suggester(dictionary: WordDictionary(entries: [
        .init(word: "the", frequency: 1000),
        .init(word: "they", frequency: 500),
        .init(word: "there", frequency: 400),
        .init(word: "their", frequency: 300),
        .init(word: "work", frequency: 200),
        .init(word: "word", frequency: 150),
        .init(word: "world", frequency: 140),
        .init(word: "hello", frequency: 120),
        .init(word: "help", frequency: 110),
        .init(word: "and", frequency: 900),
        .init(word: "a", frequency: 950),
        .init(word: "i", frequency: 940),
    ]))

    func testEmptyInputYieldsNoSuggestions() {
        XCTAssertEqual(suggester.suggest(""), .empty)
    }

    func testATransposedTypoAutocorrectsToTheFrequentWord() {
        let result = suggester.suggest("teh")
        XCTAssertEqual(result.autoCorrection, "the")
        XCTAssertTrue(result.strip.contains("the"), "the strip offers the correction")
        XCTAssertTrue(result.strip.contains("teh"), "the strip still offers the literal typing")
    }

    func testARealWordIsNotAutocorrected() {
        let result = suggester.suggest("work")
        XCTAssertNil(result.autoCorrection)
        XCTAssertTrue(result.strip.contains("work"))
    }

    func testAPrefixOffersFrequentCompletions() {
        XCTAssertEqual(suggester.suggest("th").strip.first, "the")
    }

    func testCasingIsCarriedOntoTheCorrection() {
        XCTAssertEqual(suggester.suggest("Teh").autoCorrection, "The")
        XCTAssertEqual(suggester.suggest("TEH").autoCorrection, "THE")
    }

    func testAnAdjacentKeySubstitutionIsCorrected() {
        // 'q' is adjacent to 'w': "qork" reaches "work".
        XCTAssertEqual(suggester.suggest("qork").autoCorrection, "work")
    }

    func testTheStripIsCappedAtTheLimit() {
        XCTAssertLessThanOrEqual(suggester.suggest("the").strip.count, 3)
        XCTAssertEqual(Suggester(dictionary: .init(entries: []), limit: 5).suggest("x").strip, ["x"])
    }

    func testSuggestionsAreStableAcrossCalls() {
        // The candidate set is a Set; without a total order the strip would
        // reshuffle between identical keystrokes.
        let first = suggester.suggest("wor")
        for _ in 0..<20 {
            XCTAssertEqual(suggester.suggest("wor"), first)
        }
    }
}
