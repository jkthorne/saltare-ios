import SwiftUI

/// Task states, mirroring saltare's task lifecycle.
public enum CheckState: Sendable {
    case open, progress, waiting, done, cancelled
}

/// `nier-check` — a 16pt square task checkbox. Border color carries the state;
/// `done` fills materia with a void check; `cancelled` crosses out in phoenix.
/// The hit region pads out to 28pt.
public struct NierCheck: View {
    let state: CheckState
    let action: (() -> Void)?

    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typography

    public init(state: CheckState, action: (() -> Void)? = nil) {
        self.state = state
        self.action = action
    }

    public var body: some View {
        let border: Color = {
            switch state {
            case .open: colors.arc
            case .progress: colors.materia
            case .waiting: colors.limit
            case .done: colors.materia
            case .cancelled: colors.phoenix
            }
        }()
        let fill: Color = state == .done ? colors.materia : .clear
        let glyph: String = {
            switch state {
            case .done: "✓"
            case .cancelled: "×"
            case .progress: "▸"
            case .waiting: "…"
            case .open: ""
            }
        }()
        let glyphColor: Color = {
            switch state {
            case .done: colors.void
            case .cancelled: colors.phoenix
            case .progress: colors.materia
            case .waiting: colors.limit
            case .open: .clear
            }
        }()

        let box = ZStack {
            Rectangle().fill(fill)
            if !glyph.isEmpty {
                HudText(glyph, color: glyphColor,
                        style: HudTextStyle(family: .mono, size: 10, weight: .semibold, trackingEm: 0.02))
            }
        }
        .frame(width: 16, height: 16)
        .modifier(CheckGlow(active: state == .done, glow: colors.materiaGlow))
        .overlay(Rectangle().strokeBorder(border, lineWidth: 1))
        .padding(6) // 16 + 2×6 = 28pt hit target

        if let action {
            Button(action: action) { box }
                .buttonStyle(.plain)
        } else {
            box
        }
    }
}

private struct CheckGlow: ViewModifier {
    let active: Bool
    let glow: Color
    func body(content: Content) -> some View {
        if active { content.hudGlow(glow, radius: 6) } else { content }
    }
}
