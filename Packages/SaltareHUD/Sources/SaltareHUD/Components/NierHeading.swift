import SwiftUI

/// `nier-heading` — section header: diamond/marker, tracked uppercase mono
/// label, then a chrome rule fading right. Pass natural-case `text`; the
/// component uppercases (CSS `text-transform` semantics).
public struct NierHeading<Action: View>: View {
    let text: String
    let filled: Bool
    let action: Action?

    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typography

    public init(_ text: String, filled: Bool = true, @ViewBuilder action: () -> Action) {
        self.text = text
        self.filled = filled
        self.action = action()
    }

    public var body: some View {
        HStack(spacing: 10) {
            NierMarker(status: filled ? .filled : .idle, size: .lg)
            HudText(text.uppercased(), color: colors.frost, style: typography.hudLabel)
            Rectangle()
                .fill(LinearGradient(
                    colors: [colors.chrome, colors.chrome.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
            if let action { action }
        }
    }
}

public extension NierHeading where Action == EmptyView {
    init(_ text: String, filled: Bool = true) {
        self.init(text, filled: filled) { EmptyView() }
    }
}
