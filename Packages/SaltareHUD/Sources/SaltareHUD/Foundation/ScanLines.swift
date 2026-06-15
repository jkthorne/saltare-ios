import SwiftUI

private struct ScanLinesModifier: ViewModifier {
    let color: Color
    let spacing: CGFloat
    let lineHeight: CGFloat

    func body(content: Content) -> some View {
        content.overlay(
            Canvas { ctx, size in
                var y: CGFloat = 0
                while y < size.height {
                    ctx.fill(
                        Path(CGRect(x: 0, y: y, width: size.width, height: lineHeight)),
                        with: .color(color)
                    )
                    y += spacing
                }
            }
            .allowsHitTesting(false)
            .blendMode(.overlay)
        )
    }
}

public extension View {
    /// The faint CRT scanline texture (`.scan-lines`): hairline rules every
    /// `spacing` points. Kept very low alpha — ambient, not decorative.
    func scanLines(color: Color = .black.opacity(0.06), spacing: CGFloat = 3, lineHeight: CGFloat = 1) -> some View {
        modifier(ScanLinesModifier(color: color, spacing: spacing, lineHeight: lineHeight))
    }
}
