import Foundation

/// Keyless client for demo mode — streams a fixed prompt-to-set-a-key message so
/// the agent surface works without an Anthropic API key.
public struct DemoLlmClient: LlmClient {
    public init() {}

    public func streamTurn(_ request: LlmRequest) -> AsyncStream<LlmStreamEvent> {
        let reply = "Demo mode. Add an Anthropic API key in settings to run the agent."
        return AsyncStream { continuation in
            for word in reply.split(separator: " ") {
                continuation.yield(.textDelta(String(word) + " "))
            }
            continuation.yield(.completed(stopReason: .endTurn, assistantBlocks: [.text(reply)]))
            continuation.finish()
        }
    }
}
