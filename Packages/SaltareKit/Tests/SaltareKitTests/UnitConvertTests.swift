import XCTest
@testable import SaltareKit

/// Ported from the Android `:launcher` `UnitConvertTest`.
final class UnitConvertTests: XCTestCase {

    func testLengthConversion() {
        XCTAssertEqual(UnitConvert.convert("5 km to mi"), "3.107 MI")
        XCTAssertEqual(UnitConvert.convert("1 m to cm"), "100 CM")
    }

    func testCaseAndSpacingInsensitive() {
        XCTAssertEqual(UnitConvert.convert("5 KM to MI"), "3.107 MI")
        XCTAssertEqual(UnitConvert.convert("5km to mi"), "3.107 MI")
    }

    func testTemperatureIsAffine() {
        XCTAssertEqual(UnitConvert.convert("32 f to c"), "0 C")
        XCTAssertEqual(UnitConvert.convert("100 c to f"), "212 F")
        XCTAssertEqual(UnitConvert.convert("-40 f to c"), "-40 C")
        XCTAssertEqual(UnitConvert.convert("273,15 k to c"), "0 C")
    }

    func testDataUsesBinaryMultiples() {
        XCTAssertEqual(UnitConvert.convert("1 gb to mb"), "1024 MB")
    }

    func testMassConversion() {
        XCTAssertEqual(UnitConvert.convert("1 kg to lb"), "2.205 LB")
    }

    func testUnknownUnitsYieldNoResult() {
        XCTAssertNil(UnitConvert.convert("5 km to parsecs"))
        XCTAssertNil(UnitConvert.convert("5 floops to mi"))
    }

    func testCrossDimensionYieldsNoResult() {
        XCTAssertNil(UnitConvert.convert("5 km to kg"))
        XCTAssertNil(UnitConvert.convert("5 c to mi"))
    }

    func testIncompleteQueriesYieldNoResult() {
        XCTAssertNil(UnitConvert.convert("5 km to"))
        XCTAssertNil(UnitConvert.convert("km to mi"))
        XCTAssertNil(UnitConvert.convert("5 km"))
        XCTAssertNil(UnitConvert.convert(""))
    }
}
