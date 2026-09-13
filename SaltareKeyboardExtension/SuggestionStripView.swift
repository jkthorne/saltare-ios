import SwiftUI
import SaltareHUD

/// The strip above the keys. Each suggestion is a tappable cell; the one that
/// will be applied at the next word boundary is tinted arc and the rest silver
/// — the same accent grammar the rest of the HUD uses for "this is the active
/// one".
struct SuggestionStripView: View {
    let suggestions: [String]
    let autoCorrect: String?
    let onChoose: (String) -> Void

    @Environment(\.saltareColors) private var colors
    private let typography = SaltareTypography()

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { _, word in
                Button {
                    onChoose(word)
                } label: {
                    HudText(
                        word,
                        color: word == autoCorrect ? colors.arc : colors.silver,
                        style: typography.hudLabelSmall
                    )
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(colors.carbon)
                    .contentShape(Rectangle())
                }
                .buttonStyle(HudIndicationStyle(focusColor: colors.arc))
                .accessibilityLabel(word)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.obsidian)
    }
}
