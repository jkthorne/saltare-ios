import SwiftUI
import XCTest
@testable import SaltareHUD

final class SaltareTypographyTests: XCTestCase {

    /// `em × size` → points. The web `.nier-heading__text` is 11pt / 0.14em.
    func testTrackingConvertsEmToPoints() {
        let t = SaltareTypography()
        XCTAssertEqual(t.hudLabel.tracking, 11 * 0.14, accuracy: 0.0001)
        XCTAssertEqual(t.button.tracking, 13 * 0.06, accuracy: 0.0001)
        XCTAssertEqual(t.readout.tracking, 32 * 0.05, accuracy: 0.0001)
        XCTAssertEqual(t.body.tracking, 0, accuracy: 0.0001) // display body has no tracking
    }

    func testStyleFamiliesMatchTheWebSystem() {
        let t = SaltareTypography()
        XCTAssertEqual(t.body.family, .display)   // only body is the display face…
        XCTAssertEqual(t.hudLabel.family, .mono)  // …everything HUD is mono.
        XCTAssertEqual(t.button.family, .mono)
        XCTAssertEqual(t.readout.family, .mono)
    }

    /// The web mono system never loads above 500; a 600 request maps to the
    /// medium cut (the documented Android behavior).
    func testMonoNeverExceedsMediumCut() {
        XCTAssertEqual(SaltareFont.postScriptName(.mono, .semibold), "GeistMono-Medium")
        XCTAssertEqual(SaltareFont.postScriptName(.mono, .bold), "GeistMono-Medium")
        XCTAssertEqual(SaltareFont.postScriptName(.mono, .regular), "GeistMono-Regular")
    }

    func testDisplayWeightsMapToBundledFaces() {
        XCTAssertEqual(SaltareFont.postScriptName(.display, .regular), "Geist-Regular")
        XCTAssertEqual(SaltareFont.postScriptName(.display, .medium), "Geist-Medium")
        XCTAssertEqual(SaltareFont.postScriptName(.display, .semibold), "Geist-SemiBold")
        XCTAssertEqual(SaltareFont.postScriptName(.display, .bold), "Geist-Bold")
    }

    /// The bundled Geist faces must actually register from the package bundle.
    func testFontsRegister() {
        SaltareFont.register()
        let urls = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        XCTAssertEqual(urls.count, 6, "expected the 6 Geist faces in the bundle")
    }
}
