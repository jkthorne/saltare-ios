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

    private let client: WorkspaceClient
    private let vault: TokenVault

    init(baseURL: URL, vault: TokenVault = TokenVault()) {
        self.vault = vault
        self.client = WorkspaceClient(baseURL: baseURL, tokens: vault)
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
            vault.save(tokens)
            stored = vault.stored()
        } catch {
            errorMessage = Self.describe(error)
        }
        busy = false
    }

    func signOut() async {
        busy = true
        try? await client.signOut()
        vault.clear()
        stored = nil
        busy = false
    }

    /// Rotate the access token using the refresh token (call on a 401).
    @discardableResult
    func refresh() async -> Bool {
        guard let refreshToken = vault.refreshTokenSync() else { return false }
        do {
            let tokens = try await client.refresh(refreshToken: refreshToken)
            vault.save(tokens)
            stored = vault.stored()
            return true
        } catch {
            return false
        }
    }

    private static func describe(_ error: Error) -> String {
        if let workspaceError = error as? WorkspaceError {
            switch workspaceError {
            case let .api(_, message, _): return message
            case .notAuthenticated: return "Not signed in."
            case let .http(status): return "Server error (HTTP \(status))."
            case let .transport(message): return "Network error: \(message)"
            case .decoding: return "Unexpected response from the server."
            }
        }
        return error.localizedDescription
    }
}
