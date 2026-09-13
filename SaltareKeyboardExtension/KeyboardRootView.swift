import SwiftUI
import SaltareHUD
import SaltareKeyboard

/// Fixed metrics for the input view. A keyboard has no intrinsic height, so the
/// controller constrains itself to exactly what these rows add up to.
enum KeyboardMetrics {
    static let stripHeight: CGFloat = 38
    static let rowHeight: CGFloat = 46
    static let rowSpacing: CGFloat = 5
    static let keySpacing: CGFloat = 4
    static let padding: CGFloat = 5

    /// Strip + four rows + the gaps between them + the frame's own padding.
    static var height: CGFloat {
        stripHeight + rowSpacing + 4 * rowHeight + 3 * rowSpacing + 2 * padding
    }
}

/// The whole keyboard surface: the suggestion strip over the key rows on the
/// abyss backdrop, framed once with the NieR corner brackets — the single "this
/// is a HUD module" signal, exactly as the Android `KeyboardScreen` does it.
///
/// The strip is always laid out (empty when there is nothing to suggest) so the
/// keyboard never changes height under the user's thumbs.
struct KeyboardRootView: View {
    let model: KeyboardModel

    private let colors = SaltareColors.dark

    var body: some View {
        VStack(spacing: KeyboardMetrics.rowSpacing) {
            SuggestionStripView(
                suggestions: model.suggestions,
                autoCorrect: model.autoCorrect,
                onChoose: { model.handle(.suggestionChosen($0)) }
            )
            .frame(height: KeyboardMetrics.stripHeight)

            ForEach(Array(model.rows.enumerated()), id: \.offset) { _, row in
                KeyRow(row: row, model: model)
                    .frame(height: KeyboardMetrics.rowHeight)
            }
        }
        .padding(KeyboardMetrics.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.abyss)
        .cornerBrackets(color: colors.chrome, bracketSize: 12, strokeWidth: 1.5)
        .saltareTheme(colors: colors)
    }
}

/// One row of keys. Widths are shares of the row (`Key.weight`), not equal
/// splits: SwiftUI hands flexible siblings the same width, which would make the
/// space bar exactly as wide as `M`.
private struct KeyRow: View {
    let row: [Key]
    let model: KeyboardModel

    var body: some View {
        GeometryReader { proxy in
            let spacing = KeyboardMetrics.keySpacing
            let gaps = spacing * CGFloat(max(0, row.count - 1))
            let available = max(0, proxy.size.width - gaps)
            let total = row.reduce(0) { $0 + $1.weight }
            HStack(spacing: spacing) {
                ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                    KeyView(key: key, model: model)
                        .frame(width: total > 0 ? available * CGFloat(key.weight / total) : 0)
                }
            }
        }
    }
}
