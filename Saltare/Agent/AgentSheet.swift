import SwiftUI
import SaltareHUD
import SaltareAgent

/// The agent surface: a HUD sheet with a streaming transcript, tool chips, the
/// permission GRANT affordance, and a model picker.
struct AgentSheet: View {
    let assembly: AgentAssembly
    let initialQuery: String

    @State private var model: AgentSessionModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typo

    @MainActor
    init(assembly: AgentAssembly, initialQuery: String = "") {
        self.assembly = assembly
        self.initialQuery = initialQuery
        _model = State(initialValue: AgentSessionModel(assembly: assembly))
    }

    var body: some View {
        ZStack {
            colors.abyss.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                header
                if model.phase == .streaming || model.phase == .awaitingPermission { ScanBar() }
                transcriptList
                if let permission = model.pendingPermission { grantPanel(permission) }
                if let banner = model.errorBanner { errorBanner(banner) }
                inputRow
            }
            .padding(16)
        }
        .saltareTheme(colors: .dark)
        .onAppear {
            if !initialQuery.isEmpty {
                model.input = initialQuery
                model.submit()
            }
        }
        .onDisappear { model.cancelStreaming() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            NierMarker(status: model.isStreaming ? .active : .filled, size: .lg)
            HudText("AGENT", color: colors.frost,
                    style: HudTextStyle(family: .mono, size: 15, weight: .semibold, trackingEm: 0.2))
            Spacer()
            Button { model.cycleModel() } label: {
                HudText(model.model.label, color: colors.arc, style: typo.hudLabelSmall)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .overlay(Rectangle().strokeBorder(colors.arcDim, lineWidth: 1))
            }
            .buttonStyle(HudIndicationStyle(focusColor: colors.arc))
            Button { dismiss() } label: { HudText("DONE", color: colors.silver, style: typo.hudLabelSmall) }
                .buttonStyle(HudIndicationStyle(focusColor: colors.arc))
        }
    }

    private var transcriptList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(model.transcript.enumerated()), id: \.offset) { _, message in
                    row(message)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity)
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder private func row(_ message: ChatMessage) -> some View {
        switch message {
        case let .user(text):
            HStack {
                Spacer(minLength: 32)
                HudText(text, color: colors.frost, style: typo.body)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(colors.graphite)
                    .cornerBrackets(color: colors.chrome, bracketSize: 8, strokeWidth: 1, corners: .topRightBottomLeft)
            }
        case let .agentText(text, streaming):
            HStack(alignment: .top, spacing: 8) {
                NierMarker(status: streaming ? .active : .idle, size: .sm).padding(.top, 4)
                HudText(text + (streaming ? " ▍" : ""), color: colors.ice, style: typo.body)
            }
        case let .toolChip(_, name, status):
            toolChip(name, status)
        }
    }

    private func toolChip(_ name: String, _ status: ChipStatus) -> some View {
        let (tone, detail): (BadgeTone, String?) = {
            switch status {
            case .running: return (.arc, "running…")
            case let .done(summary): return (.materia, summary)
            case let .needsPermission(permission): return (.limit, "needs \(permission)")
            case let .failed(message): return (.phoenix, message)
            }
        }()
        return HStack(alignment: .top, spacing: 8) {
            Badge(name.uppercased(), tone: tone)
            if let detail { HudText(detail, color: colors.silver, style: typo.monoBody) }
        }
    }

    private func grantPanel(_ permission: String) -> some View {
        CutPanel(compact: true) {
            VStack(alignment: .leading, spacing: 10) {
                HudText("ALLOW \(permission.uppercased()) ACCESS?", color: colors.limit, style: typo.hudLabel)
                HStack(spacing: 10) {
                    HudButton("Grant", variant: .primary) { model.grantPermission() }
                    HudButton("Deny", variant: .ghost) { model.declinePermission() }
                }
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HudText(message, color: colors.phoenix, style: typo.monoBody)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.phoenixSubtle)
            .overlay(Rectangle().strokeBorder(colors.phoenixDim, lineWidth: 1))
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            HudTextField(text: $model.input, placeholder: "Ask the agent\u{2026}")
            HudButton("Send", enabled: !model.isStreaming) { model.submit() }
        }
    }
}

#Preview {
    AgentSheet(assembly: AgentAssembly(catalog: [], launcher: UIKitLauncher()), initialQuery: "")
        .saltareTheme(colors: .dark)
}
