import SwiftUI
import SaltareHUD
import SaltareWorkspace

private enum ShareMode: String, CaseIterable { case task = "TASK", message = "MESSAGE" }

/// The Share extension's HUD form: turn shared content into a task or a channel
/// message. Reads the workspace token from the shared Keychain (`TokenVault`) and
/// posts via the `WorkspaceClient`.
struct ShareView: View {
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var detail: String
    @State private var mode: ShareMode = .task
    @State private var channels: [Channel] = []
    @State private var selectedChannelId: Int?
    @State private var status: String?
    @State private var busy = false

    private let client: WorkspaceClient
    private let signedIn: Bool
    private let workspaceName: String
    private let colors = SaltareColors.dark
    private let typo = SaltareTypography()

    init(text: String?, url: String?, onComplete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onComplete = onComplete
        self.onCancel = onCancel
        let vault = TokenVault()
        self.signedIn = vault.isSignedIn
        self.workspaceName = vault.stored()?.workspaceName ?? "saltare"
        // The extension often runs days after the app last did — an expired
        // access token here is the common case, not the edge case.
        self.client = WorkspaceClient(baseURL: URL(string: "https://saltare.ai")!, tokens: vault, refresher: vault)
        let draft = ShareDraft.from(text: text, url: url)
        _title = State(initialValue: draft.title)
        _detail = State(initialValue: draft.body)
    }

    var body: some View {
        ZStack {
            colors.abyss.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                header
                if signedIn { form } else { signedOut }
                Spacer()
            }
            .padding(18)
        }
        .saltareTheme(colors: colors)
        .task { await loadChannels() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            NierMarker(status: .active, size: .lg)
            HudText("SHARE TO \(workspaceName)".uppercased(), color: colors.frost,
                    style: HudTextStyle(family: .mono, size: 14, weight: .semibold, trackingEm: 0.16))
            Spacer()
            Button(action: onCancel) { HudText("CANCEL", color: colors.silver, style: typo.hudLabelSmall) }
                .buttonStyle(HudIndicationStyle(focusColor: colors.arc))
        }
    }

    private var signedOut: some View {
        HudText("Sign in to saltare in the app first.", color: colors.silver,
                style: HudTextStyle(family: .mono, size: 13, weight: .regular, trackingEm: 0.02))
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 12) {
            modeToggle
            HudTextField(text: $title, placeholder: "Title")
            HudTextField(text: $detail, placeholder: mode == .task ? "Description" : "Message")
            if mode == .message { channelPicker }
            if let status { HudText(status, color: colors.phoenix, style: typo.monoBody) }
            HudButton(mode == .task ? "Create task" : "Post", enabled: !busy && canSubmit) { submit() }
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 8) {
            ForEach(ShareMode.allCases, id: \.self) { item in
                Button { mode = item } label: {
                    HudText(item.rawValue, color: mode == item ? colors.arc : colors.silver,
                            style: typo.hudLabelSmall)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .overlay(Rectangle().strokeBorder(mode == item ? colors.arc : colors.panelBorder, lineWidth: 1))
                }
                .buttonStyle(HudIndicationStyle(focusColor: colors.arc))
            }
        }
    }

    private var channelPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(channels) { channel in
                    Button { selectedChannelId = channel.id } label: {
                        HudText("#\(channel.name ?? channel.slug)",
                                color: selectedChannelId == channel.id ? colors.arc : colors.silver,
                                style: typo.hudLabelSmall)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .overlay(Rectangle().strokeBorder(selectedChannelId == channel.id ? colors.arc : colors.panelBorder, lineWidth: 1))
                    }
                    .buttonStyle(HudIndicationStyle(focusColor: colors.arc))
                }
            }
        }
    }

    private var canSubmit: Bool {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return mode == .task || selectedChannelId != nil
    }

    private func loadChannels() async {
        guard signedIn else { return }
        channels = (try? await client.channels()) ?? []
    }

    private func submit() {
        guard !busy, canSubmit else { return }
        busy = true
        status = nil
        Task {
            do {
                switch mode {
                case .task:
                    _ = try await client.createTask(title: title, description: detail.isEmpty ? nil : detail)
                case .message:
                    guard let channelId = selectedChannelId else { return }
                    _ = try await client.sendMessage(channelId: channelId, body: detail.isEmpty ? title : detail)
                }
                onComplete()
            } catch {
                status = errorText(error)
                busy = false
            }
        }
    }

    private func errorText(_ error: Error) -> String {
        if case let WorkspaceError.api(_, message, _) = error { return message }
        return "Couldn't share. Check your connection and try again."
    }
}
