import Foundation
import Security
import SaltareWorkspace

/// Keychain-sealed workspace session — the `sk_sal_` access token, the `rt_sal_`
/// refresh token, and a little metadata for display. Conforms to
/// `TokenProviding` so the `WorkspaceClient` reads the access token through it.
/// Device-only (`...ThisDeviceOnly`); the source of truth shared by the
/// `WorkspaceSession` UI and the agent's inference-proxy credential.
struct TokenVault: TokenProviding {
    struct Stored: Codable, Sendable, Equatable {
        var access: String
        var refresh: String
        var workspaceSlug: String
        var workspaceName: String
        var userEmail: String
    }

    private let service = "ai.saltare.workspace"
    private let account = "session"

    func stored() -> Stored? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(Stored.self, from: data)
    }

    /// Sync read for the agent's credential resolver.
    func accessTokenSync() -> String? { stored()?.access }
    func refreshTokenSync() -> String? { stored()?.refresh }
    var isSignedIn: Bool { stored() != nil }

    // TokenProviding
    func accessToken() async -> String? { accessTokenSync() }

    func save(_ tokens: AuthTokens) {
        let stored = Stored(
            access: tokens.accessToken,
            refresh: tokens.refreshToken,
            workspaceSlug: tokens.workspace.slug,
            workspaceName: tokens.workspace.name,
            userEmail: tokens.user.email
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        clear()
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func clear() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ] as CFDictionary)
    }
}
