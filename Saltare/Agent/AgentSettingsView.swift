import SwiftUI
import SaltareHUD

/// Agent settings — paste the Anthropic API key (sealed in the Keychain).
struct AgentSettingsView: View {
    let keyStore: KeyStoring

    @State private var keyInput = ""
    @State private var hasKey: Bool
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typo

    @MainActor
    init(keyStore: KeyStoring) {
        self.keyStore = keyStore
        _hasKey = State(initialValue: keyStore.hasKey)
    }

    var body: some View {
        ZStack {
            colors.abyss.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    NierHeading("Agent Key")
                    Button { dismiss() } label: { HudText("DONE", color: colors.silver, style: typo.hudLabelSmall) }
                        .buttonStyle(HudIndicationStyle(focusColor: colors.arc))
                }

                HudText(hasKey ? "A key is set." : "No key set — the agent runs once you add one.",
                        color: hasKey ? colors.materia : colors.silver, style: typo.monoBody)

                VStack(alignment: .leading, spacing: 6) {
                    HudText("ANTHROPIC API KEY", color: colors.mist, style: typo.hudLabel)
                    SecureField("", text: $keyInput, prompt: Text(verbatim: "sk-ant-…").foregroundColor(colors.silver))
                        .textFieldStyle(.plain)
                        .font(typo.body.font)
                        .foregroundStyle(colors.frost)
                        .tint(colors.arc)
                        .focused($focused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(colors.carbon)
                        .overlay(Rectangle().strokeBorder(focused ? colors.arc : colors.chrome, lineWidth: 1))
                }

                HStack(spacing: 10) {
                    HudButton("Save", enabled: !keyInput.trimmingCharacters(in: .whitespaces).isEmpty) {
                        keyStore.save(keyInput.trimmingCharacters(in: .whitespaces))
                        keyInput = ""
                        hasKey = true
                        focused = false
                    }
                    HudButton("Clear", variant: .danger, enabled: hasKey) {
                        keyStore.clear()
                        hasKey = false
                    }
                }

                HudText("Stored in the device Keychain (never synced or logged). Get a key at console.anthropic.com.",
                        color: colors.silver, style: typo.monoBody)
                Spacer()
            }
            .padding(16)
        }
        .saltareTheme(colors: .dark)
    }
}
