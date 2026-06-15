import XCTest
@testable import SaltareKit

/// Ported from the Android `:launcher` `CalculatorTest`.
final class CalculatorTests: XCTestCase {

    func testPrecedenceAndParens() {
        XCTAssertEqual(Calculator.evaluate("2+3*4"), "14")
        XCTAssertEqual(Calculator.evaluate("(2+3)*4"), "20")
        XCTAssertEqual(Calculator.evaluate("10/(2+3)"), "2")
    }

    func testPowerIsRightAssociative() {
        XCTAssertEqual(Calculator.evaluate("2^3^2"), "512")
    }

    func testUnaryMinus() {
        XCTAssertEqual(Calculator.evaluate("-3+5"), "2")
        XCTAssertEqual(Calculator.evaluate("2*-3"), "-6")
        XCTAssertEqual(Calculator.evaluate("-(2+2)"), "-4")
        XCTAssertEqual(Calculator.evaluate("-2^2"), "-4") // -(2^2), the convention
    }

    func testModuloAndDivision() {
        XCTAssertEqual(Calculator.evaluate("7%3"), "1")
        XCTAssertEqual(Calculator.evaluate("7/2"), "3.5")
    }

    func testDivisionByZeroYieldsNoResult() {
        XCTAssertNil(Calculator.evaluate("5/0")) // Infinity must never render
        XCTAssertNil(Calculator.evaluate("0/0")) // NaN either
    }

    func testOverflowYieldsNoResult() {
        XCTAssertNil(Calculator.evaluate("999999999^999"))
    }

    func testWholeNumbersRenderBare() {
        XCTAssertEqual(Calculator.evaluate("2*3"), "6")
        XCTAssertEqual(Calculator.evaluate("5-5"), "0")
    }

    func testPrecisionCapsAtTenSignificantDigits() {
        XCTAssertEqual(Calculator.evaluate("1/3"), "0.3333333333")
    }

    func testCommaIsADecimalSeparator() {
        XCTAssertEqual(Calculator.evaluate("3,5+1"), "4.5")
    }

    func testBareNumbersAreNotExpressions() {
        // No operator → app search wins ("2048" the game, not the number).
        XCTAssertNil(Calculator.evaluate("2048"))
        XCTAssertNil(Calculator.evaluate("  42 "))
        XCTAssertNil(Calculator.evaluate("-5")) // a lone negative is still bare
    }

    func testGarbageNeverThrows() {
        let junk = [
            "", "   ", "++", "(((", ")(", "()", "5+", "-", "5km to", "abc",
            "1..2", "2,,3", "1.2.3", "5//2", "^2", "2^", "(2+3", "2+3)", "🦊+1",
        ]
        for q in junk {
            XCTAssertNil(Calculator.evaluate(q), "expected nil for: \"\(q)\"")
        }
    }
}
