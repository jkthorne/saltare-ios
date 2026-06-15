import CoreGraphics

/// Spacing, radius, and border-width tokens. The web system's
/// `--spacing-unit: 0.5rem` maps to an 8pt base; radii are deliberately
/// near-rectangular (0–2pt) and borders hairline-thin.
public struct SaltareSpacing: Equatable, Sendable {
    public var unit: CGFloat = 8
    public var xs: CGFloat = 4
    public var sm: CGFloat = 8
    public var md: CGFloat = 12
    public var lg: CGFloat = 16
    public var xl: CGFloat = 24
    /// `--radius-sharp` — most components.
    public var radiusSharp: CGFloat = 1
    /// `--radius-cut` / `--radius-panel` — modals, panels, alerts.
    public var radiusCut: CGFloat = 2
    /// Standard 1px border.
    public var borderThin: CGFloat = 1
    /// 1.5px — subtle corner brackets (panels, avatars).
    public var borderMid: CGFloat = 1.5
    /// 2px — prominent brackets (nier-panel, cut-panel).
    public var borderThick: CGFloat = 2

    public init() {}
}
