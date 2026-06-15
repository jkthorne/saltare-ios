import Foundation

/// SDK-free LLM boundary. The Anthropic implementation (URLSession SSE) lands in
/// the data layer (iP2.2); tests use scripted fakes. One `streamTurn` call =
/// one API request.
public protocol LlmClient: Sendable {
    func streamTurn(_ request: LlmRequest) -> AsyncStream<LlmStreamEvent>
}

public struct LlmRequest: Sendable {
    public let model: AgentModel
    public let history: [HistoryMessage]
    public let tools: [ToolSpec]

    public init(model: AgentModel, history: [HistoryMessage], tools: [ToolSpec]) {
        self.model = model
        self.history = history
        self.tools = tools
    }
}

public enum StopReason: Sendable, Equatable {
    case endTurn, toolUse, maxTokens, refusal, other
}

public enum LlmStreamEvent: Sendable, Equatable {
    /// Visible text token(s).
    case textDelta(String)
    /// The full turn finished. `assistantBlocks` is the complete accumulated
    /// assistant content (text, tool_use, thinking w/ signature) to echo into
    /// history verbatim.
    case completed(stopReason: StopReason, assistantBlocks: [AssistantBlock])
    case failed(message: String, retryable: Bool)
}
