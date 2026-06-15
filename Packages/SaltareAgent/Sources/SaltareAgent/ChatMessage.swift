import Foundation

/// What the conversation UI renders. Ported from the Android `:agent`
/// `ChatMessage`.
public enum ChatMessage: Equatable, Sendable {
    case user(String)
    /// The agent's reply; `streaming` true while it's the live (growing) message.
    case agentText(text: String, streaming: Bool)
    case toolChip(id: String, name: String, status: ChipStatus)
}

public enum ChipStatus: Equatable, Sendable {
    case running
    case done(String)
    case needsPermission(String)
    case failed(String)
}

public enum AgentPhase: Sendable {
    case idle, streaming, awaitingPermission, error
}
