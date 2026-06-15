import SwiftUI

/// Which corners carry the L-shaped bracket accents. The web system's default
/// is top-left + bottom-right (`hud-panel`, `nier-panel`); `cut-panel` uses all
/// four.
public enum BracketCorners: Sendable {
    case topLeftBottomRight
    case topRightBottomLeft
    case all
}

private struct CornerBracketsModifier: ViewModifier {
    let color: Color
    let bracketSize: CGFloat
    let strokeWidth: CGFloat
    let corners: BracketCorners

    func body(content: Content) -> some View {
        // Brackets render ON TOP of content (CSS `z-index: 1`).
        content.overlay(
            Canvas { ctx, size in
                let s = bracketSize
                let w = max(1, strokeWidth) // hairline clamp for low-density screens
                func bracket(_ topLeft: CGPoint, _ size: CGSize) {
                    ctx.fill(Path(CGRect(origin: topLeft, size: size)), with: .color(color))
                }
                func topLeft() {
                    bracket(.zero, CGSize(width: s, height: w))
                    bracket(.zero, CGSize(width: w, height: s))
                }
                func topRight() {
                    bracket(CGPoint(x: size.width - s, y: 0), CGSize(width: s, height: w))
                    bracket(CGPoint(x: size.width - w, y: 0), CGSize(width: w, height: s))
                }
                func bottomLeft() {
                    bracket(CGPoint(x: 0, y: size.height - w), CGSize(width: s, height: w))
                    bracket(CGPoint(x: 0, y: size.height - s), CGSize(width: w, height: s))
                }
                func bottomRight() {
                    bracket(CGPoint(x: size.width - s, y: size.height - w), CGSize(width: s, height: w))
                    bracket(CGPoint(x: size.width - w, y: size.height - s), CGSize(width: w, height: s))
                }
                switch corners {
                case .topLeftBottomRight: topLeft(); bottomRight()
                case .topRightBottomLeft: topRight(); bottomLeft()
                case .all: topLeft(); topRight(); bottomLeft(); bottomRight()
                }
            }
            .allowsHitTesting(false)
        )
    }
}

public extension View {
    /// The signature NieR visual: L-shaped corner brackets, drawn as filled
    /// rects (CSS draws them as borders of empty `::before`/`::after` boxes —
    /// filled rects reproduce that exactly and dodge stroke center-alignment).
    func cornerBrackets(
        color: Color,
        bracketSize: CGFloat = 12,
        strokeWidth: CGFloat = 1.5,
        corners: BracketCorners = .topLeftBottomRight
    ) -> some View {
        modifier(CornerBracketsModifier(
            color: color,
            bracketSize: bracketSize,
            strokeWidth: strokeWidth,
            corners: corners
        ))
    }
}
