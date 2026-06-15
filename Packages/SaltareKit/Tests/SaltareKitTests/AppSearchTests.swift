import XCTest
@testable import SaltareKit

/// Ported from the Android `:launcher` `AppSearchTest` (minus the work-profile
/// section, which has no iOS analog).
final class AppSearchTests: XCTestCase {

    private let signal = app("Signal")
    private let simpleNotes = app("Simple Notes")
    private let camera = app("Camera")
    private let eclair = app("Éclair Recipes")
    private let fdroid = app("F-Droid")
    private lazy var apps = [camera, eclair, fdroid, signal, simpleNotes] // collator order

    private func hits(_ query: String) -> [String] {
        AppSearch.search(apps, query).compactMap {
            if case let .appHit(a) = $0 { return a.label }
            return nil
        }
    }

    func testNormalizeStripsDiacriticsCaseAndPunctuation() {
        XCTAssertEqual(AppSearch.normalize("Éclair, Recipes!"), "eclair recipes")
    }

    func testBlankQueryReturnsEverything() {
        XCTAssertEqual(hits("").count, apps.count)
    }

    func testWordPrefixOutranksContains() {
        XCTAssertEqual(hits("si"), ["Signal", "Simple Notes"])
        XCTAssertEqual(hits("notes"), ["Simple Notes"])
        XCTAssertEqual(hits("mer"), ["Camera"]) // substring of "Camera", ranked after prefixes
    }

    func testDiacriticInsensitiveMatch() {
        XCTAssertEqual(hits("ecl"), ["Éclair Recipes"])
    }

    func testPunctuationIsAWordBreak() {
        XCTAssertEqual(hits("droid"), ["F-Droid"]) // word-prefix of second token
        XCTAssertEqual(hits("fdr"), ["F-Droid"])   // joined form
    }

    func testRanksExactOverPrefixOverSubstringOverSubsequence() {
        let crafted = [app("Norton Tea"), app("Keynote"), app("Notepad"), app("Note")]
        let labels = AppSearch.search(crafted, "note").compactMap {
            if case let .appHit(a) = $0 { return a.label }; return nil
        }
        // exact, word-prefix, substring, subsequence (n-o-t-e in "nortontea")
        XCTAssertEqual(labels, ["Note", "Notepad", "Keynote", "Norton Tea"])
    }

    func testSubsequenceNeedsThreeChars() {
        XCTAssertEqual(hits("sgn"), ["Signal"])
        // Two chars: subsequence off; zero hits falls through to the stub.
        let only = AppSearch.search(apps, "sg")
        XCTAssertEqual(only.count, 1)
        XCTAssertEqual(only.first, .agentStub(query: "sg"))
    }

    func testMultiWordPhrasePrefixMatches() {
        XCTAssertEqual(hits("simple n"), ["Simple Notes"])
    }

    func testEqualRanksKeepInputOrder() {
        XCTAssertEqual(hits("si"), ["Signal", "Simple Notes"])
        let reversed = AppSearch.search([simpleNotes, signal], "si").compactMap {
            if case let .appHit(a) = $0 { return a.label }; return nil
        }
        XCTAssertEqual(reversed, ["Simple Notes", "Signal"])
    }

    func testZeroHitsYieldsAgentStubCarryingQuery() {
        let results = AppSearch.search(apps, "weather tomorrow")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, .agentStub(query: "weather tomorrow"))
    }

    // MARK: - assembly: Calc → AppHits → Links → AgentStub

    func testWeakHitsAppendTheAgentStub() {
        let results = AppSearch.search(apps, "sgn") // only subsequence-matches Signal
        XCTAssertEqual(results.first, .appHit(signal))
        if case .agentStub = results.last { } else { XCTFail("expected trailing agent stub") }
    }

    func testStrongHitsSuppressTheAgentStub() {
        XCTAssertFalse(AppSearch.search(apps, "cam").contains { if case .agentStub = $0 { return true }; return false })
    }

    func testCalcRowPrependsAndCountsAsStrong() {
        let results = AppSearch.search(apps, "2+3")
        XCTAssertEqual(results.first, .calc(expression: "2+3", display: "5"))
        XCTAssertFalse(results.contains { if case .agentStub = $0 { return true }; return false })
    }

    func testUnitConversionAlsoYieldsACalcRow() {
        XCTAssertEqual(AppSearch.search(apps, "5 km to mi").first, .calc(expression: "5 km to mi", display: "3.107 MI"))
    }

    func testAppsNamedLikeNumbersBeatTheCalculator() {
        let results = AppSearch.search([app("2048")], "2048")
        XCTAssertEqual(results.first, .appHit(app("2048")))
        XCTAssertFalse(results.contains { if case .calc = $0 { return true }; return false })
    }

    private let testLinks = [
        SettingsLinkDef(id: "wifi", label: "Wi-Fi", target: .appSettings, keywords: ["wifi", "network"]),
        SettingsLinkDef(id: "display", label: "Display", target: .appSettings, keywords: ["display", "network"]),
        SettingsLinkDef(id: "sound", label: "Sound", target: .appSettings, keywords: ["sound", "network"]),
    ]

    func testSettingsLinksRankBelowAppHitsAndSuppressTheStub() {
        let display = app("Display")
        let results = AppSearch.search([display], "display", links: testLinks)
        XCTAssertEqual(results[0], .appHit(display))
        if case let .settingsLink(def) = results[1] { XCTAssertEqual(def.id, "display") } else { XCTFail() }
        XCTAssertFalse(results.contains { if case .agentStub = $0 { return true }; return false })
    }

    func testSettingsLinksCapAtTwoRows() {
        let links = AppSearch.search(apps, "network", links: testLinks).filter {
            if case .settingsLink = $0 { return true }; return false
        }
        XCTAssertEqual(links.count, 2)
    }

    // MARK: - contact splice

    func testContactsSpliceBeforeTheAgentStub() {
        let contact = SearchResult.contact(name: "Marta Kowalski", number: "+48123456789")
        let base: [SearchResult] = [.agentStub(query: "marta")]
        XCTAssertEqual(AppSearch.withContacts(base, [contact]), [contact, .agentStub(query: "marta")])
    }

    func testContactsAppendWhenNoStubExists() {
        let contact = SearchResult.contact(name: "Marta Kowalski", number: "+48123456789")
        let base = AppSearch.search(apps, "cam") // strong hit, no stub
        let merged = AppSearch.withContacts(base, [contact])
        XCTAssertEqual(merged.last, contact)
        XCTAssertEqual(Array(merged.dropLast()), base)
    }

    func testEmptyContactsLeaveResultsUntouched() {
        let base = AppSearch.search(apps, "cam")
        XCTAssertEqual(AppSearch.withContacts(base, []), base)
    }

    // MARK: - auto-launch guard rails

    private func candidate(_ prev: String, _ query: String, enabled: Bool = true) -> AppEntry? {
        AppSearch.autoLaunchCandidate(previousQuery: prev, query: query,
                                      results: AppSearch.search(apps, query), enabled: enabled)
    }

    func testAutoLaunchFiresOnUniquePrefixWhileTypingForward() {
        XCTAssertEqual(candidate("ca", "cam"), camera)
    }

    func testAutoLaunchRespectsToggle() {
        XCTAssertNil(candidate("ca", "cam", enabled: false))
    }

    func testAutoLaunchNeedsTwoChars() {
        XCTAssertNil(candidate("", "c"))
    }

    func testAutoLaunchNeverFiresOnDeletion() {
        XCTAssertNil(candidate("came", "cam")) // shrinking
        XCTAssertNil(candidate("cam", "cam"))  // unchanged
    }

    func testAutoLaunchNeedsExactlyOneHit() {
        XCTAssertNil(candidate("s", "si")) // Signal + Simple Notes
    }

    func testAutoLaunchRejectsMidWordSubstring() {
        XCTAssertNil(candidate("me", "mer")) // unique but not a word prefix
    }

    func testAutoLaunchRejectsSubsequence() {
        XCTAssertNil(candidate("sgn", "sgna"))
    }

    func testAutoLaunchNeverFiresOnAgentStub() {
        XCTAssertNil(candidate("xyz", "xyzq"))
    }

    func testAutoLaunchNeverFiresWhenACalcRowIsPresent() {
        XCTAssertNil(candidate("2*", "2*3"))
    }
}
