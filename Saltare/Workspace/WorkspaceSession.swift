import Foundation
import Observation
import UIKit
import SaltareWorkspace

/// Drives native sign-in and holds the signed-in state. The `TokenVault` (the
/// Keychain) is the source of truth — both this and the agent read it — so
/// signing in here immediately gives the agent the workspace token.
@MainActor
@Observable
final class WorkspaceSession {
    private(set) var stored: TokenVault.Stored?
    private(set) var errorMessage: String?
    private(set) var busy = false

    let client: WorkspaceClient
    /// The Action Cable client for live channel messages — same token vault, so
    /// it authenticates as soon as the user is signed in.
    let realtime: RealtimeClient
    private let vault: TokenVault

    init(baseURL: URL, vault: TokenVault = TokenVault()) {
        self.vault = vault
        self.client = WorkspaceClient(baseURL: baseURL, tokens: vault, refresher: vault)
        self.realtime = RealtimeClient(baseURL: baseURL, tokens: vault)
        self.stored = vault.stored()
    }

    var isSignedIn: Bool { stored != nil }

    func signIn(email: String, password: String) async {
        let email = email.trimmingCharacters(in: .whitespaces)
        guard !email.isEmpty, !password.isEmpty else { return }
        busy = true
        errorMessage = nil
        do {
            let tokens = try await client.signIn(email: email, password: password, deviceName: UIDevice.current.name)
            // The server said yes but the Keychain said no (an unentitled build,
            // most often). Without this the form just sits there: no session, no
            // error, nothing to react to.
            guard vault.save(tokens) else {
                errorMessage = "Signed in, but this device wouldn't store the session. Check the app's Keychain access."
                busy = false
                return
            }
            stored = vault.stored()
        } catch {
            errorMessage = workspaceErrorText(error)
        }
        busy = false
    }

    func signOut() async {
        busy = true
        try? await client.signOut()
        vault.clear()
        SpotlightIndexer.shared.clear() // drop indexed workspace items
        WorkspaceSnapshotStore.clear()  // drop the widget snapshot
        stored = nil
        busy = false
    }

    /// Re-read the vault. The `WorkspaceClient` rotates tokens on a 401 behind
    /// everyone's back — and drops the session when the refresh token is refused
    /// — so the signed-in state shown here can go stale between screens.
    func syncFromVault() {
        stored = vault.stored()
    }
}
