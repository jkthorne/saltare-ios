import SwiftUI

/// `hud-panel` — the primary container: translucent panel surface, 1pt hairline
/// border, 12pt/1.5pt chrome corner brackets. Pass an `accent` for the 2pt top
/// edge strip.
public struct HudPanel<Content: View>: View {
    let accent: HudAccent?
    let contentPadding: CGFloat
    let content: Content

    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareSpacing) private var spacing

    public init(accent: HudAccent? = nil, contentPadding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.contentPadding = contentPadding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.panel)
            .overlay(Rectangle().strokeBorder(colors.panelBorder, lineWidth: spacing.borderThin))
            .overlay(alignment: .top) {
                if let accent {
                    Rectangle().fill(accent.base(colors)).frame(height: 2)
                }
            }
            .cornerBrackets(color: colors.chrome, bracketSize: 12, strokeWidth: spacing.borderMid)
    }
}

/// `nier-panel` — the prominent container: 16pt/2pt frost brackets, solid
/// border, generous padding. For transmissions and dossiers.
public struct NierPanel<Content: View>: View {
    let accent: HudAccent?
    let content: Content

    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareSpacing) private var spacing

    public init(accent: HudAccent? = nil, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.panel)
            .overlay(Rectangle().strokeBorder(colors.panelBorder, lineWidth: spacing.borderThin))
            .cornerBrackets(color: accent?.base(colors) ?? colors.frost, bracketSize: 16, strokeWidth: spacing.borderThick)
    }
}

/// `cut-panel` — all four corners carry brackets. The "Cybertruck angular"
/// variant for standalone callouts.
public struct CutPanel<Content: View>: View {
    let compact: Bool
    let content: Content

    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareSpacing) private var spacing

    public init(compact: Bool = false, @ViewBuilder content: () -> Content) {
        self.compact = compact
        self.content = content()
    }

    public var body: some View {
        content
            .padding(compact ? 16 : 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.panel)
            .overlay(Rectangle().strokeBorder(colors.panelBorder, lineWidth: spacing.borderThin))
            .cornerBrackets(color: colors.frost, bracketSize: 14, strokeWidth: spacing.borderThick, corners: .all)
    }
}

/// `.divider` — 1pt rule fading out at both ends.
public struct HudDivider: View {
    @Environment(\.saltareColors) private var colors
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(LinearGradient(
                stops: [
                    .init(color: colors.chrome.opacity(0), location: 0),
                    .init(color: colors.chrome, location: 0.5),
                    .init(color: colors.chrome.opacity(0), location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            ))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}
