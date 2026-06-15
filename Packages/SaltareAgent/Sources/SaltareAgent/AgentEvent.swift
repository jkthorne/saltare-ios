import Foundation

/// Output of one `AgentLoop` user turn — what the conversation UI consumes.
public enum AgentEvent: Sendable, Equatable {
    case textDelta(String)
    case toolCallStarted(id: String, name: String, input: [String: JSONValue])
    case toolResultReady(id: String, name: String, outcome: ToolOutcome)
    case turnComplete
    case error(message: String, retryable: Bool)
}
