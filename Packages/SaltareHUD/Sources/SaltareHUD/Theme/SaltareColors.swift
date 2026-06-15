import SwiftUI

/// Packed-ARGB color helper. The Android `:hud` library ports CSS `#RRGGBBAA`
/// to Compose `0xAARRGGBB`; we keep that exact literal format here so the two
/// platforms read from the same numbers (and the token tests stay 1:1).
public extension Color {
    /// Build a color from a packed `0xAARRGGBB` value (the Compose port format).
    init(argb: UInt32) {
        let a = Double((argb >> 24) & 0xFF) / 255.0
        let r = Double((argb >> 16) & 0xFF) / 255.0
        let g = Double((argb >> 8) & 0xFF) / 255.0
        let b = Double(argb & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// Saltare color tokens, ported 1:1 from the web design system
/// (`saltare/app/assets/tailwind/application.css`) by way of the Android
/// `:hud` library's `SaltareColors`.
///
/// CSS hex is `#RRGGBBAA`; the literals below are `0xAARRGGBB` — the alpha byte
/// moves to the front. `dark` and `light` are both hand-written full palettes:
/// light is *not* derivable from dark (`arcBright` inverts to a darker shade,
/// glow alphas drop from `0x44` to `0x30`).
public struct SaltareColors: Equatable, Sendable {
    // Neutrals — deep blacks, warm-shifted grays (dark) / parchment (light)
    public let void: Color
    public let abyss: Color
    public let obsidian: Color
    public let carbon: Color
    public let graphite: Color
    public let steel: Color
    public let titanium: Color
    public let chrome: Color
    public let silver: Color
    public let mist: Color
    public let frost: Color
    public let ice: Color
    public let white: Color
    // Primary accent — arc (cyan, "android diagnostic")
    public let arc: Color
    public let arcDim: Color
    public let arcBright: Color
    public let arcGlow: Color
    public let arcSubtle: Color
    // Status — materia (operational green)
    public let materia: Color
    public let materiaDim: Color
    public let materiaGlow: Color
    public let materiaSubtle: Color
    // Status — limit (warning amber)
    public let limit: Color
    public let limitDim: Color
    public let limitGlow: Color
    public let limitSubtle: Color
    // Status — phoenix (critical red)
    public let phoenix: Color
    public let phoenixDim: Color
    public let phoenixGlow: Color
    public let phoenixSubtle: Color
    // Surface — translucent panel layers
    public let panel: Color
    public let panelSolid: Color
    public let panelHover: Color
    public let panelActive: Color
    public let panelBorder: Color
    public let panelBorderHover: Color
    public let isLight: Bool

    public static let dark = SaltareColors(
        void: Color(argb: 0xFF000000),
        abyss: Color(argb: 0xFF060608),
        obsidian: Color(argb: 0xFF0B0B10),
        carbon: Color(argb: 0xFF121218),
        graphite: Color(argb: 0xFF1B1B24),
        steel: Color(argb: 0xFF262630),
        titanium: Color(argb: 0xFF30303D),
        chrome: Color(argb: 0xFF3B3B4D),
        silver: Color(argb: 0xFF8888A0),
        mist: Color(argb: 0xFF9A9AAD),
        frost: Color(argb: 0xFFCDCDDD),
        ice: Color(argb: 0xFFEAE8E2),
        white: Color(argb: 0xFFF2F0EA),
        arc: Color(argb: 0xFF00C8F0),
        arcDim: Color(argb: 0xFF0094B2),
        arcBright: Color(argb: 0xFF60DCF8),
        arcGlow: Color(argb: 0x4400C8F0),
        arcSubtle: Color(argb: 0x1400C8F0),
        materia: Color(argb: 0xFF00E880),
        materiaDim: Color(argb: 0xFF00BB62),
        materiaGlow: Color(argb: 0x4400E880),
        materiaSubtle: Color(argb: 0x1400E880),
        limit: Color(argb: 0xFFF0A000),
        limitDim: Color(argb: 0xFFC08000),
        limitGlow: Color(argb: 0x44F0A000),
        limitSubtle: Color(argb: 0x14F0A000),
        phoenix: Color(argb: 0xFFF03050),
        phoenixDim: Color(argb: 0xFFC02840),
        phoenixGlow: Color(argb: 0x44F03050),
        phoenixSubtle: Color(argb: 0x14F03050),
        panel: Color(argb: 0xCC0D0D1A),
        panelSolid: Color(argb: 0xFF0D0D1A),
        panelHover: Color(argb: 0x99141422),
        panelActive: Color(argb: 0xBB1A1A2D),
        panelBorder: Color(argb: 0x10FFFFFF),
        panelBorderHover: Color(argb: 0x1EFFFFFF),
        isLight: false
    )

    /// "NieR menu parchment".
    public static let light = SaltareColors(
        void: Color(argb: 0xFFF0EBE2),
        abyss: Color(argb: 0xFFE8E2D8),
        obsidian: Color(argb: 0xFFDDD7CC),
        carbon: Color(argb: 0xFFF4EFE6),
        graphite: Color(argb: 0xFFE4DED2),
        steel: Color(argb: 0xFFD4CDC0),
        titanium: Color(argb: 0xFFC6BFB2),
        chrome: Color(argb: 0xFFAEA798),
        silver: Color(argb: 0xFF6B645A),
        mist: Color(argb: 0xFF5A5448),
        frost: Color(argb: 0xFF2E2A24),
        ice: Color(argb: 0xFF1E1A15),
        white: Color(argb: 0xFF100E0A),
        arc: Color(argb: 0xFF1A7A9E),
        arcDim: Color(argb: 0xFF15627D),
        arcBright: Color(argb: 0xFF13536B),
        arcGlow: Color(argb: 0x301A7A9E),
        arcSubtle: Color(argb: 0x101A7A9E),
        materia: Color(argb: 0xFF1A8A5A),
        materiaDim: Color(argb: 0xFF156E48),
        materiaGlow: Color(argb: 0x301A8A5A),
        materiaSubtle: Color(argb: 0x101A8A5A),
        limit: Color(argb: 0xFFAA7A00),
        limitDim: Color(argb: 0xFF886200),
        limitGlow: Color(argb: 0x30AA7A00),
        limitSubtle: Color(argb: 0x10AA7A00),
        phoenix: Color(argb: 0xFFC42A3E),
        phoenixDim: Color(argb: 0xFF9E2232),
        phoenixGlow: Color(argb: 0x30C42A3E),
        phoenixSubtle: Color(argb: 0x10C42A3E),
        panel: Color(argb: 0xCCFAF6EE),
        panelSolid: Color(argb: 0xFFFAF6EE),
        panelHover: Color(argb: 0xAAF0EBE2),
        panelActive: Color(argb: 0xBBE8E2D8),
        panelBorder: Color(argb: 0x10000000),
        panelBorderHover: Color(argb: 0x1E000000),
        isLight: true
    )
}
