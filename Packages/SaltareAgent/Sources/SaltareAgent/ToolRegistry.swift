import Foundation

/// The agent's tool catalog. Order is DELIBERATE and stable — the rendered tool
/// list is part of the prompt-cache prefix, so reordering invalidates it. MCP
/// `saltare__*` tools always append AFTER every local tool.
public final class ToolRegistry: @unchecked Sendable {
    public let localTools: [ToolSpec]

    private let lock = NSLock()
    private var _remoteTools: [ToolSpec] = []

    public init(localTools: [ToolSpec]) {
        self.localTools = localTools
    }

    /// MCP workspace tools, set once connected (iP3). Appended last.
    public var remoteTools: [ToolSpec] {
        get { lock.lock(); defer { lock.unlock() }; return _remoteTools }
        set { lock.lock(); _remoteTools = newValue; lock.unlock() }
    }

    public var tools: [ToolSpec] { localTools + remoteTools }

    public func find(_ name: String) -> ToolSpec? { tools.first { $0.name == name } }
}
