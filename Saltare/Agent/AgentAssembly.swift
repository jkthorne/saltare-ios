import Foundation
import SaltareKit
import SaltareAgent

/// Wires the agent: command-surface capabilities → tool registry → executor →
/// loop, with the Anthropic client. Credentials resolve per request: a signed-in
/// workspace token routes to the saltare inference proxy (server-held key); a
/// pasted Anthropic key routes direct. The agent sheet (iP2.4) drives
/// `loop.runStream` with `tools` and `awaitPermission`.
struct AgentAssembly: Sendable {
    let loop: AgentLoop
    let tools: [ToolSpec]
    let keyStore: KeyStoring
    private let workspaceToken: @Sendable () -> String?

    init(
        catalog: [AppEntry],
        launcher: AppLaunching,
        keyStore: KeyStoring = KeychainApiKeyStore(),
        workspaceBaseURL: URL,
        workspaceToken: @escaping @Sendable () -> String?
    ) {
        let capabilities = CommandSurfaceCapabilities(catalog: catalog, launcher: launcher)
        let registry = ToolRegistry(localTools: AgentTools.local(capabilities: capabilities))
        let executor = ToolExecutor(registry: registry, permissionGranted: AgentPermissions.granted)

        let config = AnthropicConfig(
            volatile: { model in
                SystemPromptText.volatile(now: Date(), timeZone: .current, locale: .current, model: model)
            },
            endpoint: {
                // Prefer the workspace: the inference proxy holds the Anthropic
                // key + meters credits, so no key needs to live on-device.
                if let token = workspaceToken(), !token.isEmpty {
                    return AnthropicEndpoint(
                        baseURL: workspaceBaseURL.appendingPathComponent("api/v1/inference"),
                        credential: .bearer(token)
                    )
                }
                if let key = keyStore.load(), !key.isEmpty {
                    return AnthropicEndpoint(baseURL: URL(string: "https://api.anthropic.com")!, credential: .apiKey(key))
                }
                return nil
            }
        )

        self.loop = AgentLoop(llm: AnthropicLlmClient(config: config), executor: executor)
        self.tools = registry.tools
        self.keyStore = keyStore
        self.workspaceToken = workspaceToken
    }

    /// True when the agent can authenticate — a workspace session or a pasted key.
    var hasCredentials: Bool { workspaceToken()?.isEmpty == false || keyStore.hasKey }

    /// The loop's GRANT-flow handler — requests the iOS permission for the tool.
    func awaitPermission(_ permission: String) async -> Bool {
        await AgentPermissions.request(permission)
    }
}
