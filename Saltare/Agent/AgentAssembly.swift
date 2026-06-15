import Foundation
import SaltareKit
import SaltareAgent

/// Wires the agent: command-surface capabilities → tool registry → executor →
/// loop, with the Anthropic client (or demo, keyless). Built from the app graph;
/// the agent sheet (iP2.4) drives `loop.runStream` with `tools` and
/// `awaitPermission`.
struct AgentAssembly: Sendable {
    let loop: AgentLoop
    let tools: [ToolSpec]
    let keyStore: KeyStoring

    init(catalog: [AppEntry], launcher: AppLaunching, keyStore: KeyStoring = KeychainApiKeyStore()) {
        let capabilities = CommandSurfaceCapabilities(catalog: catalog, launcher: launcher)
        let registry = ToolRegistry(localTools: AgentTools.local(capabilities: capabilities))
        let executor = ToolExecutor(registry: registry, permissionGranted: AgentPermissions.granted)

        let config = AnthropicConfig(
            volatile: { model in
                SystemPromptText.volatile(now: Date(), timeZone: .current, locale: .current, model: model)
            },
            apiKey: { keyStore.load() }
        )
        let llm: LlmClient = keyStore.hasKey ? AnthropicLlmClient(config: config) : DemoLlmClient()

        self.loop = AgentLoop(llm: llm, executor: executor)
        self.tools = registry.tools
        self.keyStore = keyStore
    }

    /// The loop's GRANT-flow handler — requests the iOS permission for the tool.
    func awaitPermission(_ permission: String) async -> Bool {
        await AgentPermissions.request(permission)
    }
}
