import SwiftUI
import SaltareHUD
import SaltareKit

/// The command surface — the app's front door. One HUD field is the universal
/// input; deterministic results render below in the row-order contract. iP1.0
/// is the shell: the engine is live, row *actions* land in iP1.2.
struct CommandSurfaceView: View {
    @State private var model: CommandSurfaceModel

    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typo

    init(graph: AppGraph) {
        _model = State(initialValue: CommandSurfaceModel(search: graph.search))
    }

    var body: some View {
        let queryBinding = Binding(
            get: { model.query },
            set: { model.setQuery($0) }
        )

        ZStack {
            colors.abyss.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                header
                ScanBar()
                HudTextField(
                    text: queryBinding,
                    placeholder: "Search, calc, or ask the agent\u{2026}"
                )
                results
            }
            .padding(20)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            NierMarker(status: .active, size: .lg)
            HudText("SALTARE", color: colors.frost,
                    style: HudTextStyle(family: .mono, size: 16, weight: .semibold, trackingEm: 0.22))
            Spacer()
            HudText("CMD", color: colors.silver, style: typo.hudLabelSmall)
        }
    }

    private var results: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(model.results.enumerated()), id: \.offset) { index, result in
                    CommandRow(result: result, onSelect: select)
                    if index < model.results.count - 1 {
                        HudDivider()
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// Placeholder selection sink. iP1.2 routes app hits to a launcher, calc to
    /// the clipboard, contacts to call/SMS; iP2 wires the agent stub.
    private func select(_ result: SearchResult) {
        // intentionally inert for the iP1.0 shell
    }
}

#Preview {
    CommandSurfaceView(graph: AppGraph())
        .saltareTheme(colors: .dark)
}
