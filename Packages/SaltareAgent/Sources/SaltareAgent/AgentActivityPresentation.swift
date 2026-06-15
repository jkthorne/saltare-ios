import Foundation

/// A presentation snapshot for the agent-turn Live Activity — already-formatted
/// strings so the widget extension renders it without depending on this package.
public struct AgentActivitySnapshot: Equatable, Sendable {
    public let statusLabel: String
    public let detail: String
    public let isActive: Bool

    public init(statusLabel: String, detail: String, isActive: Bool) {
        self.statusLabel = statusLabel
        self.detail = detail
        self.isActive = isActive
    }
}

/// Pure mapping from the agent's phase to the Live Activity content — kept here
/// (testable) so the app + widget stay dumb renderers.
public enum AgentActivityPresentation {
    public static func snapshot(phase: AgentPhase, toolCount: Int, lastTool: String?) -> AgentActivitySnapshot {
        switch phase {
        case .idle:
            return AgentActivitySnapshot(
                statusLabel: "DONE",
                detail: toolCount > 0 ? "\(toolCount) \(toolCount == 1 ? "tool" : "tools")" : "Complete",
                isActive: false
            )
        case .streaming:
            return AgentActivitySnapshot(
                statusLabel: "THINKING",
                detail: lastTool.map { "Running \($0)" } ?? "Working…",
                isActive: true
            )
        case .awaitingPermission:
            return AgentActivitySnapshot(
                statusLabel: "PERMISSION",
                detail: lastTool.map { "Allow \($0)?" } ?? "Awaiting grant",
                isActive: true
            )
        case .error:
            return AgentActivitySnapshot(statusLabel: "ERROR", detail: "Tap to view", isActive: false)
        }
    }
}
