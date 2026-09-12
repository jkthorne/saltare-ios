import Foundation
import Security
import SaltareWorkspace

/// Keychain-sealed workspace session — the `sk_sal_` access token, the `rt_sal_`
/// refresh token, and a little metadata for display. Conforms to
/// `TokenProviding` so the `WorkspaceClient` reads the access token through it.
/// Device-only (`...ThisDeviceOnly`); the source of truth shared by the
/// `WorkspaceSession` UI and the agent's inference-proxy credential.
///
/// Stored in a shared Keychain access group so the Share extension (a separate
/// process) reads the same token. On unsigned simulator builds the access group
/// isn't entitled, so Keychain ops no-op (return nil) — live sign-in needs a
/// signed build, which was always the case.
struct TokenVault: TokenProviding, TokenRefreshing {
    struct Stored: Codable, Sendable, Equatable {
        var access: String
        var refresh: String
        var workspaceSlug: String
        var workspaceName: String
        var userEmail: String
    }

    /// Matches the `keychain-access-groups` entitlement on the app + Share
    /// extension; the team prefix is supplied by the entitlement at sign time.
    static let sharedAccessGroup = "ai.saltare.shared"

    private let service = "ai.saltare.workspace"
    private let account = "session"
    private let accessGroup: String?

    init(accessGroup: String? = TokenVault.sharedAccessGroup) {
        self.accessGroup = accessGroup
    }

    private func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }

    func stored() -> Stored? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
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

    // TokenRefreshing — the client rotates through here on a 401, so an expired
    // access token never surfaces to the UI as a failed load.
    func refreshToken() async -> String? { refreshTokenSync() }
    func accept(_ tokens: AuthTokens) async { save(tokens) }
    func invalidate() async { clear() }

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
        var attributes = baseQuery()
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}
