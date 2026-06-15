import SwiftUI

public enum HudButtonVariant: Sendable {
    case primary, secondary, danger, ghost
}

/// `btn-*` — rectangular, mono, uppercase. No ripple: the `HudIndicationStyle`
/// supplies the press-scale. Pass natural-case `title`; the button uppercases
/// (CSS `text-transform: uppercase`).
public struct HudButton: View {
    let title: String
    let variant: HudButtonVariant
    let enabled: Bool
    let action: () -> Void

    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typography

    public init(
        _ title: String,
        variant: HudButtonVariant = .primary,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.enabled = enabled
        self.action = action
    }

    public var body: some View {
        let (bg, fg, border): (Color, Color, Color) = {
            switch variant {
            case .primary: (colors.arc, colors.void, colors.arc)
            case .secondary: (.clear, colors.frost, colors.chrome)
            case .danger: (colors.phoenix, colors.white, colors.phoenix)
            case .ghost: (.clear, colors.silver, colors.panelBorder)
            }
        }()

        Button(action: action) {
            HudText(title.uppercased(), color: fg, style: typography.button)
                .frame(minHeight: 40)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(bg)
                .overlay(Rectangle().strokeBorder(border, lineWidth: 1))
        }
        .buttonStyle(HudIndicationStyle(focusColor: colors.arc, enabled: enabled))
        .disabled(!enabled)
        .fixedSize(horizontal: true, vertical: false)
    }
}
