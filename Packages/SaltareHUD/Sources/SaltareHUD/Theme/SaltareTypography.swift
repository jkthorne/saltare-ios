import SwiftUI

/// A HUD text style. Ports the web utility classes (and the Android
/// `SaltareTypography`): size is rem×16 → pt, letter-spacing carries over in
/// `em`. `HudText` applies the resolved font and tracking.
///
/// Uppercase is applied by components (CSS `text-transform` semantics) — styles
/// never transform text, and APIs take natural case.
public struct HudTextStyle: Equatable, Sendable {
    public let family: HudFontFamily
    public let size: CGFloat
    public let weight: Font.Weight
    /// Letter-spacing in `em`, as authored in the web system.
    public let trackingEm: CGFloat

    public init(family: HudFontFamily, size: CGFloat, weight: Font.Weight = .regular, trackingEm: CGFloat = 0) {
        self.family = family
        self.size = size
        self.weight = weight
        self.trackingEm = trackingEm
    }

    /// SwiftUI `.tracking` is in points; `em × size` converts.
    public var tracking: CGFloat { trackingEm * size }

    public var font: Font { SaltareFont.resolve(family: family, size: size, weight: weight) }
}

/// The system's text styles, ported token-for-token from the web utilities.
public struct SaltareTypography: Equatable, Sendable {
    /// `.nier-heading__text` — mono 11 / 600 / 0.14em, uppercase at call site.
    public var hudLabel = HudTextStyle(family: .mono, size: 11, weight: .semibold, trackingEm: 0.14)
    /// `.dossier-field-label` — mono 9 / 0.12em, uppercase at call site.
    public var hudLabelSmall = HudTextStyle(family: .mono, size: 9, weight: .medium, trackingEm: 0.12)
    /// `.btn-*` — mono 13 / 500 / 0.06em, uppercase at call site.
    public var button = HudTextStyle(family: .mono, size: 13, weight: .medium, trackingEm: 0.06)
    /// Default body copy — display face.
    public var body = HudTextStyle(family: .display, size: 14, weight: .regular)
    /// `.font-mono-hud` — mono 13 / 0.02em.
    public var monoBody = HudTextStyle(family: .mono, size: 13, weight: .regular, trackingEm: 0.02)
    /// `.nier-readout` — mono 32 / 400 / 0.05em data numerals.
    public var readout = HudTextStyle(family: .mono, size: 32, weight: .regular, trackingEm: 0.05)
    /// `.nier-readout--sm`.
    public var readoutSmall = HudTextStyle(family: .mono, size: 24, weight: .regular, trackingEm: 0.05)
    /// `.nier-timestamp` — mono 10 / 0.08em.
    public var timestamp = HudTextStyle(family: .mono, size: 10, weight: .regular, trackingEm: 0.08)
    /// `.badge` — mono 10 / 600 / 0.06em, uppercase at call site.
    public var badge = HudTextStyle(family: .mono, size: 10, weight: .semibold, trackingEm: 0.06)

    public init() {}
}
