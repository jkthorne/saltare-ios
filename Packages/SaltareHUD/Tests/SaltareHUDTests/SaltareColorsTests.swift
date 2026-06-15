import SwiftUI
import XCTest
@testable import SaltareHUD

/// Mirrors the Android `SaltareColorsTest`: every token is asserted against its
/// exact `0xAARRGGBB` literal so a typo in the port can't slip through. The web
/// `application.css` is the source of truth — update both together.
final class SaltareColorsTests: XCTestCase {

    func testArgbHelperUnpacksChannels() {
        // Opaque arc cyan: 0xFF00C8F0 → r=0x00 g=0xC8 b=0xF0 a=0xFF.
        let (r, g, b, a) = components(of: 0xFF00C8F0)
        XCTAssertEqual(r, 0x00 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(g, 0xC8 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(b, 0xF0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(a, 1.0, accuracy: 0.0001)

        // Translucent glow: 0x4400C8F0 → alpha 0x44.
        XCTAssertEqual(components(of: 0x4400C8F0).a, Double(0x44) / 255.0, accuracy: 0.0001)
    }

    func testDarkPaletteTokens() {
        let c = SaltareColors.dark
        XCTAssertEqual(c.void, Color(argb: 0xFF000000))
        XCTAssertEqual(c.abyss, Color(argb: 0xFF060608))
        XCTAssertEqual(c.carbon, Color(argb: 0xFF121218))
        XCTAssertEqual(c.chrome, Color(argb: 0xFF3B3B4D))
        XCTAssertEqual(c.frost, Color(argb: 0xFFCDCDDD))
        XCTAssertEqual(c.white, Color(argb: 0xFFF2F0EA))
        XCTAssertEqual(c.arc, Color(argb: 0xFF00C8F0))
        XCTAssertEqual(c.arcGlow, Color(argb: 0x4400C8F0))
        XCTAssertEqual(c.arcSubtle, Color(argb: 0x1400C8F0))
        XCTAssertEqual(c.materia, Color(argb: 0xFF00E880))
        XCTAssertEqual(c.limit, Color(argb: 0xFFF0A000))
        XCTAssertEqual(c.phoenix, Color(argb: 0xFFF03050))
        XCTAssertEqual(c.panel, Color(argb: 0xCC0D0D1A))
        XCTAssertEqual(c.panelBorder, Color(argb: 0x10FFFFFF))
        XCTAssertFalse(c.isLight)
    }

    func testLightPaletteIsHandWrittenNotDerived() {
        let c = SaltareColors.light
        // Parchment, not an inversion: light arc is a *darker* teal.
        XCTAssertEqual(c.arc, Color(argb: 0xFF1A7A9E))
        // arcBright inverts to an even darker shade in light (the documented quirk).
        XCTAssertEqual(c.arcBright, Color(argb: 0xFF13536B))
        // Glow alphas drop 0x44 → 0x30 in light.
        XCTAssertEqual(c.arcGlow, Color(argb: 0x301A7A9E))
        XCTAssertEqual(c.void, Color(argb: 0xFFF0EBE2))
        XCTAssertEqual(c.panelBorder, Color(argb: 0x10000000))
        XCTAssertTrue(c.isLight)
    }

    // MARK: - Helpers

    private func components(of argb: UInt32) -> (r: Double, g: Double, b: Double, a: Double) {
        (
            Double((argb >> 16) & 0xFF) / 255.0,
            Double((argb >> 8) & 0xFF) / 255.0,
            Double(argb & 0xFF) / 255.0,
            Double((argb >> 24) & 0xFF) / 255.0
        )
    }
}
