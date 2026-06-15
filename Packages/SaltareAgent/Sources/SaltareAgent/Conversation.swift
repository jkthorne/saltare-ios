import Foundation

/// Assistant content blocks, mirrored SDK-free so they echo into history
/// verbatim across requests.
public enum AssistantBlock: Sendable, Equatable {
    case text(String)
    case toolUse(id: String, name: String, input: [String: JSONValue])
    /// `signature` must be echoed untouched or the next request 400s.
    case thinking(text: String, signature: String)
    /// Opaque; echoed verbatim.
    case redactedThinking(data: String)
}

/// One tool result, paired to a `tool_use` id from the preceding assistant turn.
public struct ToolResult: Sendable, Equatable {
    public let toolUseId: String
    public let text: String
    public let isError: Bool

    public init(toolUseId: String, text: String, isError: Bool) {
        self.toolUseId = toolUseId
        self.text = text
        self.isError = isError
    }
}

public enum HistoryMessage: Sendable, Equatable {
    case user(String)
    case assistant([AssistantBlock])
    /// One result per `tool_use` id from the preceding assistant turn.
    case toolResults([ToolResult])
}

/// The conversation history, owned across turns (the loop appends to it as it
/// runs). A reference type with internal locking so the loop's task mutates it
/// safely; the UI reads `messages` between turns.
public final class AgentHistory: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [HistoryMessage]

    public init(_ messages: [HistoryMessage] = []) {
        self.storage = messages
    }

    public var messages: [HistoryMessage] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    func append(_ message: HistoryMessage) {
        lock.lock(); defer { lock.unlock() }
        storage.append(message)
    }

    func removeLast() {
        lock.lock(); defer { lock.unlock() }
        if !storage.isEmpty { storage.removeLast() }
    }
}
