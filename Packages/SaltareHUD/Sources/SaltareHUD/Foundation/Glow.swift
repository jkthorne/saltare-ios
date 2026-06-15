import SwiftUI

private struct HudGlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        // Port of the CSS shadow tokens: `0 0 12px {color}20, 0 0 24px {color}10`
        // — two soft halos behind the element, never a heavy bloom.
        content
            .shadow(color: color.opacity(0.125), radius: radius)       // 0x20
            .shadow(color: color.opacity(0.0625), radius: radius * 2)  // 0x10
    }
}

public extension View {
    /// Restrained ambient glow. Pass the token's *glow* color (already carries
    /// its base alpha); the modifier layers two halos at decreasing strength.
    func hudGlow(_ color: Color, radius: CGFloat = 12) -> some View {
        modifier(HudGlowModifier(color: color, radius: radius))
    }
}
