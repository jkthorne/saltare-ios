import XCTest
@testable import SaltareKit

final class ContactSearchTests: XCTestCase {

    private let contacts = [
        Contact(name: "Marta Kowalski", number: "+48 123 456 789"),
        Contact(name: "Mark Twain", number: "+1 555 0100"),
        Contact(name: "Éric Dupont", number: "+33 1 23 45"),
        Contact(name: "Alice", number: "+1 555 0199"),
    ]

    func testWordPrefixMatchesFirstOrLastNameToken() {
        XCTAssertEqual(ContactSearch.search(contacts, query: "mar").map(\.name), ["Marta Kowalski", "Mark Twain"])
        XCTAssertEqual(ContactSearch.search(contacts, query: "kow").map(\.name), ["Marta Kowalski"]) // second token
    }

    func testDiacriticInsensitive() {
        XCTAssertEqual(ContactSearch.search(contacts, query: "eric").map(\.name), ["Éric Dupont"])
    }

    func testBlankQueryReturnsNothing() {
        XCTAssertTrue(ContactSearch.search(contacts, query: "   ").isEmpty)
    }

    func testRespectsLimit() {
        XCTAssertEqual(ContactSearch.search(contacts, query: "a", limit: 1).count, 1)
    }
}
