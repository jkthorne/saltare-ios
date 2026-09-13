import XCTest
@testable import SaltareKeyboard

/// Structural checks on the static layouts, ported from the Android
/// `LayoutsTest` and extended with the iOS-only globe key.
final class LayoutsTests: XCTestCase {

    func testLettersHasTheQwertyTopRow() {
        let top = Layouts.rows(.letters)[0]
        XCTAssertEqual(top.compactMap(\.character), Array("qwertyuiop"))
    }

    func testEveryPageHasFourRows() {
        for page in LayoutPage.allCases {
            XCTAssertEqual(Layouts.rows(page).count, 4, "\(page) row count")
        }
    }

    func testLetterAndSymbolPagesEndWithSpaceAndEnter() {
        for page in [LayoutPage.letters, .symbolsOne, .symbolsTwo] {
            let bottom = Layouts.rows(page)[3]
            XCTAssertTrue(bottom.contains(.space), "\(page) has a space key")
            XCTAssertTrue(bottom.contains(.enter), "\(page) has an enter key")
        }
    }

    func testNoDuplicateCharactersWithinAPage() {
        for page in LayoutPage.allCases {
            let characters = Layouts.rows(page).flatMap { $0 }.compactMap(\.character)
            XCTAssertEqual(characters.count, Set(characters).count, "\(page) has no duplicate characters")
        }
    }

    func testSymbolPagesCanRoundTripBackToLetters() {
        for page in [LayoutPage.symbolsOne, .symbolsTwo] {
            let targets = Layouts.rows(page).flatMap { $0 }.compactMap { key -> LayoutPage? in
                if case let .page(target, _) = key { return target }
                return nil
            }
            XCTAssertTrue(targets.contains(.letters), "\(page) can return to letters")
        }
    }

    func testLetterTopRowCarriesDigitAlternates() {
        let top = Layouts.rows(.letters)[0]
        XCTAssertEqual(top.compactMap(\.alternate), Array("1234567890"))
    }

    func testTheGlobeKeyIsOptedIntoNotAssumed() {
        for page in LayoutPage.allCases {
            let plain = Layouts.rows(page).flatMap { $0 }
            XCTAssertFalse(plain.contains(.globe), "\(page) has no globe key by default")

            let switchable = Layouts.rows(page, globe: true)
            XCTAssertEqual(
                switchable.flatMap { $0 }.filter { $0 == .globe }.count,
                1,
                "\(page) gets exactly one globe key"
            )
            XCTAssertTrue(switchable[3].contains(.globe), "\(page) puts it in the bottom row")
        }
    }

    func testTheGlobeKeyDoesNotDisplaceAnything() {
        for page in LayoutPage.allCases {
            let plain = Layouts.rows(page).flatMap { $0 }
            let switchable = Layouts.rows(page, globe: true).flatMap { $0 }.filter { $0 != .globe }
            XCTAssertEqual(plain, switchable, "\(page) keeps every other key")
        }
    }
}
