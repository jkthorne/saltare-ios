import SwiftUI

/// The custom saltare mark (`heroicons/solid/nier-diamond.svg`): a filled outer
/// diamond with a subtle inner diamond outline. Drawn on a 24×24 viewport and
/// scaled to `size`.
public struct NierDiamond: View {
    let color: Color
    let size: CGFloat

    public init(color: Color, size: CGFloat = 24) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        Canvas { ctx, canvas in
            let scale = min(canvas.width, canvas.height) / 24.0
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * scale, y: y * scale) }

            var outer = Path()
            outer.move(to: p(12, 3.5))
            outer.addLine(to: p(20.5, 12))
            outer.addLine(to: p(12, 20.5))
            outer.addLine(to: p(3.5, 12))
            outer.closeSubpath()
            ctx.fill(outer, with: .color(color))

            var inner = Path()
            inner.move(to: p(12, 7.5))
            inner.addLine(to: p(16.5, 12))
            inner.addLine(to: p(12, 16.5))
            inner.addLine(to: p(7.5, 12))
            inner.closeSubpath()
            ctx.stroke(inner, with: .color(color.opacity(0.35)), lineWidth: scale)
        }
        .frame(width: size, height: size)
    }
}
