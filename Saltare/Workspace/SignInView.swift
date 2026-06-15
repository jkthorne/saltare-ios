import SwiftUI
import SaltareHUD

/// Native sign-in to a saltare workspace (email + password → a device session).
/// When signed in, shows the workspace + a sign-out button.
struct SignInView: View {
    @Bindable var session: WorkspaceSession

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.saltareColors) private var colors
    @Environment(\.saltareTypography) private var typo

    private enum Field { case email, password }

    var body: some View {
        ZStack {
            colors.abyss.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    NierHeading("Saltare Workspace")
                    Button { dismiss() } label: { HudText("DONE", color: colors.silver, style: typo.hudLabelSmall) }
                        .buttonStyle(HudIndicationStyle(focusColor: colors.arc))
                }
                if session.busy { ScanBar() }

                if let stored = session.stored {
                    signedIn(stored)
                } else {
                    signInForm
                }
                Spacer()
            }
            .padding(16)
        }
        .saltareTheme(colors: .dark)
    }

    private func signedIn(_ stored: TokenVault.Stored) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            NierReadout(value: stored.workspaceName, label: "Workspace")
            HudText(stored.userEmail, color: colors.silver, style: typo.monoBody)
            Badge("Connected", tone: .materia)
            HudButton("Sign out", variant: .danger, enabled: !session.busy) {
                Task { await session.signOut() }
            }
        }
    }

    private var signInForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HudText("Sign in to connect the agent, chat, tasks, and docs to your workspace.",
                    color: colors.silver, style: typo.monoBody)
            field("EMAIL") {
                TextField("", text: $email, prompt: Text(verbatim: "you@company.com").foregroundColor(colors.silver))
                    .keyboardType(.emailAddress).textContentType(.username)
                    .focused($focus, equals: .email)
            }
            field("PASSWORD") {
                SecureField("", text: $password, prompt: Text(verbatim: "••••••••").foregroundColor(colors.silver))
                    .textContentType(.password)
                    .focused($focus, equals: .password)
            }
            if let error = session.errorMessage {
                HudText(error, color: colors.phoenix, style: typo.monoBody)
            }
            HudButton("Sign in", enabled: !session.busy && !email.isEmpty && !password.isEmpty) {
                focus = nil
                Task { await session.signIn(email: email, password: password) }
            }
        }
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
    }

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HudText(label, color: colors.mist, style: typo.hudLabel)
            content()
                .textFieldStyle(.plain)
                .font(typo.body.font)
                .foregroundStyle(colors.frost)
                .tint(colors.arc)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(colors.carbon)
                .overlay(Rectangle().strokeBorder(colors.chrome, lineWidth: 1))
        }
    }
}
