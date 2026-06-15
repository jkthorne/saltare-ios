import SwiftUI

/// `badge` tones — the four accents plus a graphite neutral.
public enum BadgeTone: Sendable {
    case neutral, arc, materia, limit, phoenix
}

/// `badge` — uppercase mono pill: subtle tinted background, dim 1pt border,
/// accent text. Pass natural-case `text`; the component uppercases.
public struct Badge: View {
    let text: String
    let tone: BadgeTone

    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typography

    public init(_ text: String, tone: BadgeTone = .neutral) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        let accent: HudAccent? = {
            switch tone {
            case .neutral: nil
            case .arc: .arc
            case .materia: .materia
            case .limit: .limit
            case .phoenix: .phoenix
            }
        }()
        let textColor = accent?.base(colors) ?? colors.mist
        let borderColor = accent?.dim(colors) ?? colors.steel
        let bg = accent?.subtle(colors) ?? colors.graphite

        HudText(text.uppercased(), color: textColor, style: typography.badge)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(bg)
            .overlay(Rectangle().strokeBorder(borderColor, lineWidth: 1))
    }
}
