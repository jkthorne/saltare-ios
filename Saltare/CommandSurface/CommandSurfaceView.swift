import SwiftUI
import SaltareHUD
import SaltareKit

/// The command surface — the app's front door. One HUD field is the universal
/// input; deterministic results render below in the row-order contract, each
/// row wired to its action (launch / copy / call / grant).
struct CommandSurfaceView: View {
    @State private var model: CommandSurfaceModel
    private let router = CommandRouter.shared
    private let agent: AgentAssembly

    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typo

    @MainActor
    init(graph: AppGraph) {
        _model = State(initialValue: CommandSurfaceModel(graph: graph))
        agent = graph.agent
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
        .overlay(alignment: .bottom) { toast }
        .onChange(of: router.pendingQuery) { _, newValue in
            // App Intents / widget / Control routed a query here.
            guard let query = newValue else { return }
            model.setQuery(query)
            router.pendingQuery = nil
        }
        .sheet(item: Binding(get: { model.presentedRoute }, set: { model.presentedRoute = $0 })) { route in
            switch route {
            case let .agent(query): AgentSheet(assembly: agent, initialQuery: query)
            case .agentSettings: AgentSettingsView(keyStore: agent.keyStore)
            }
        }
        .task {
            // UI-test / screenshot hook (no-op in normal use).
            if ProcessInfo.processInfo.environment["SALTARE_PRESENT_AGENT"] != nil {
                model.presentedRoute = .agent(query: "")
            }
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
                    CommandRow(result: result) { model.select($0) }
                    if index < model.results.count - 1 {
                        HudDivider()
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder private var toast: some View {
        if let message = model.toast {
            HudText(message, color: colors.arcBright, style: typo.monoBody)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(colors.panelSolid)
                .cornerBrackets(color: colors.arc, bracketSize: 10, strokeWidth: 1.5)
                .padding(.bottom, 28)
                .transition(.opacity)
        }
    }
}

#Preview {
    CommandSurfaceView(graph: AppGraph())
        .saltareTheme(colors: .dark)
}
