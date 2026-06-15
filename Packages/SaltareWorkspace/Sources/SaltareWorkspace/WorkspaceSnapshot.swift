import Foundation

/// A small, Codable digest of the workspace the app writes to a shared App Group
/// container for the workspace Widget to read — so the widget (out-of-process)
/// renders recent channels + tasks without needing the token or network. Plain
/// fields + deep links; the mapping from the REST models is here (pure, tested).
public struct WorkspaceSnapshot: Codable, Hashable, Sendable {
    public struct Item: Codable, Hashable, Sendable, Identifiable {
        public let id: String       // deep link (saltare://…) — the widget's tap target
        public let title: String
        public let subtitle: String
        public init(id: String, title: String, subtitle: String) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
        }
    }

    public let workspaceName: String
    public let channels: [Item]
    public let tasks: [Item]
    public let updatedAt: Date

    public init(workspaceName: String, channels: [Item], tasks: [Item], updatedAt: Date) {
        self.workspaceName = workspaceName
        self.channels = channels
        self.tasks = tasks
        self.updatedAt = updatedAt
    }

    /// Build a snapshot from freshly-loaded collections: the first `limit`
    /// channels, and the first `limit` open (not completed/cancelled) tasks.
    public static func make(
        workspaceName: String,
        channels: [Channel],
        tasks: [WorkspaceTask],
        limit: Int = 4,
        now: Date
    ) -> WorkspaceSnapshot {
        let channelItems = channels.prefix(limit).map { channel in
            Item(
                id: "saltare://workspace",
                title: "#\(channel.name ?? channel.slug)",
                subtitle: "\(channel.messagesCount ?? 0) messages"
            )
        }
        let openTasks = tasks.filter { $0.state != "completed" && $0.state != "cancelled" }
        let taskItems = openTasks.prefix(limit).map { task in
            Item(
                id: "saltare://task/\(task.slug)",
                title: task.title,
                subtitle: [task.state, task.dueDate.map { "due \($0)" }].compactMap { $0 }.joined(separator: " · ")
            )
        }
        return WorkspaceSnapshot(
            workspaceName: workspaceName,
            channels: Array(channelItems),
            tasks: Array(taskItems),
            updatedAt: now
        )
    }
}
