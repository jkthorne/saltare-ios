import SwiftUI

/// `nier-marker` status variants.
public enum MarkerStatus: Sendable {
    case idle, active, warning, danger, success, filled
}

/// `nier-marker` sizes (xs 4 / sm 5 / md 6 / lg 8).
public enum MarkerSize: CGFloat, Sendable {
    case xs = 4, sm = 5, md = 6, lg = 8
}

/// The universal NieR indicator: a 45°-rotated square. Idle is a chrome
/// outline; status variants fill with their accent; `active` additionally glows.
public struct NierMarker: View {
    let status: MarkerStatus
    let size: MarkerSize

    @Environment(\.saltareColors) private var colors

    public init(status: MarkerStatus = .idle, size: MarkerSize = .md) {
        self.status = status
        self.size = size
    }

    public var body: some View {
        let (border, fill): (Color, Color?) = {
            switch status {
            case .idle: (colors.chrome, nil)
            case .active: (colors.arc, colors.arc)
            case .warning: (colors.limit, colors.limit)
            case .danger: (colors.phoenix, colors.phoenix)
            case .success: (colors.materia, colors.materia)
            case .filled: (colors.frost, colors.frost)
            }
        }()

        Rectangle()
            .fill(fill ?? .clear)
            .overlay(Rectangle().strokeBorder(border, lineWidth: 1))
            .frame(width: size.rawValue, height: size.rawValue)
            .rotationEffect(.degrees(45))
            .modifier(MarkerGlow(active: status == .active, glow: colors.arcGlow))
    }
}

private struct MarkerGlow: ViewModifier {
    let active: Bool
    let glow: Color
    func body(content: Content) -> some View {
        if active { content.hudGlow(glow, radius: 4) } else { content }
    }
}
