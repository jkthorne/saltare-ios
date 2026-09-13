import XCTest
@testable import SaltareKeyboard

/// Ported from the Android `CorrectorTest` — a fixture dictionary, never the
/// shipped asset, so the expectations stay readable.
final class CorrectorTests: XCTestCase {

    private let corrector = Corrector(dictionary: WordDictionary(entries: [
        .init(word: "work", frequency: 200),
        .init(word: "word", frequency: 150),
        .init(word: "the", frequency: 1000),
        .init(word: "hello", frequency: 100),
    ]))

    func testADeletionTypoIsCorrected() {
        XCTAssertTrue(corrector.candidates("workk").contains("work"))
    }

    func testAnInsertionTypoIsCorrected() {
        XCTAssertTrue(corrector.candidates("wrk").contains("work"))
    }

    func testCandidatesAreRankedByFrequency() {
        // "worl" reaches "work" by the adjacent l/k substitution; when several
        // candidates are in reach the most frequent one leads.
        XCTAssertEqual(corrector.candidates("worl").first, "work")
    }

    func testANonAdjacentSubstitutionIsNotOffered() {
        // 'z' is nowhere near 'w': "zork" must not become "work".
        XCTAssertFalse(corrector.candidates("zork").contains("work"))
    }

    func testTheWordItselfIsNeverItsOwnCandidate() {
        XCTAssertFalse(corrector.candidates("work").contains("work"))
    }
}
