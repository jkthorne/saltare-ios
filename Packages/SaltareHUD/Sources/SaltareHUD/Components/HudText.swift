import SwiftUI

/// The system's `Text`: reads the ambient `hudTextStyle` and `hudContentColor`
/// from the environment and applies the style's font + tracking, since
/// Material's `Text` is deliberately not on the classpath.
///
/// Resolution order for color: explicit `color:` → the style's own color
/// (unused here) → ambient `hudContentColor` → `frost`.
public struct HudText: View {
    private let text: String
    private let explicitColor: Color?
    private let explicitStyle: HudTextStyle?

    @Environment(\.hudTextStyle) private var ambientStyle
    @Environment(\.hudContentColor) private var ambientColor
    @Environment(\.saltareColors) private var colors

    public init(_ text: String, color: Color? = nil, style: HudTextStyle? = nil) {
        self.text = text
        self.explicitColor = color
        self.explicitStyle = style
    }

    public var body: some View {
        let style = explicitStyle ?? ambientStyle ?? SaltareTypography().body
        let color = explicitColor ?? ambientColor ?? colors.frost
        Text(text)
            .font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(color)
    }
}
