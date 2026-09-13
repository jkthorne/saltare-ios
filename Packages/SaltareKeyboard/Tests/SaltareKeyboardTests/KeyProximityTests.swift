import XCTest
@testable import SaltareKeyboard

final class KeyProximityTests: XCTestCase {

    func testAdjacentKeysAreNeighbours() {
        XCTAssertTrue(KeyProximity.neighbors(of: "q").contains("w"))
        XCTAssertTrue(KeyProximity.neighbors(of: "s").isSuperset(of: Set("adwe")))
    }

    func testAdjacencyIsSymmetric() {
        for row in ["qwertyuiop", "asdfghjkl", "zxcvbnm"] {
            for character in row {
                for neighbor in KeyProximity.neighbors(of: character) {
                    XCTAssertTrue(
                        KeyProximity.neighbors(of: neighbor).contains(character),
                        "\(character) and \(neighbor) disagree"
                    )
                }
            }
        }
    }

    func testDistantKeysAreNotNeighbours() {
        XCTAssertFalse(KeyProximity.neighbors(of: "q").contains("p"))
        XCTAssertFalse(KeyProximity.neighbors(of: "q").contains("z"))
    }

    func testAnythingOffTheLetterGridHasNoNeighbours() {
        XCTAssertTrue(KeyProximity.neighbors(of: "1").isEmpty)
    }
}
