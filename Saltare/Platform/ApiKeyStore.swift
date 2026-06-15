import Foundation
import Security

/// Stores the Anthropic API key. The agent's `AnthropicConfig.apiKey` closure
/// reads through this; demo mode runs when there's no key.
protocol KeyStoring: Sendable {
    func load() -> String?
    func save(_ value: String)
    func clear()
}

extension KeyStoring {
    var hasKey: Bool { load()?.isEmpty == false }
}

/// Keychain-backed store. The secret is encrypted at rest and excluded from
/// backups (`...ThisDeviceOnly`). It is *not* biometric-gated: the agent reads
/// it on every request, and a Face ID prompt per turn would be hostile — the
/// device passcode is the protection boundary. A biometric-gated variant
/// (`SecAccessControl(.biometryCurrentSet)`) is the upgrade path if a
/// "lock the agent" setting is added.
struct KeychainApiKeyStore: KeyStoring {
    private let service = "ai.saltare.anthropic"
    private let account = "api-key"

    func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    func save(_ value: String) {
        clear()
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
