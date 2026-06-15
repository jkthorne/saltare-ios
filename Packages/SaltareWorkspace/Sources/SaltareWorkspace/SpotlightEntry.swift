import Foundation

/// A platform-free description of one CoreSpotlight item. The app turns these
/// into `CSSearchableItem`s (CoreSpotlight is UIKit-adjacent); keeping the
/// mapping here makes it pure + testable and co-located with the models.
///
/// `identifier` doubles as the deep link opened when the Spotlight result is
/// tapped — `saltare://task/<slug>` / `saltare://document/<slug>`.
public struct SpotlightEntry: Sendable, Equatable {
    public let identifier: String
    public let domainIdentifier: String
    public let title: String
    public let contentDescription: String?
    public let keywords: [String]

    public init(identifier: String, domainIdentifier: String, title: String, contentDescription: String?, keywords: [String]) {
        self.identifier = identifier
        self.domainIdentifier = domainIdentifier
        self.title = title
        self.contentDescription = contentDescription
        self.keywords = keywords
    }
}

/// Maps workspace models to `SpotlightEntry`s. `domainIdentifier`s group items
/// so a re-index can replace a whole type at once.
public enum SpotlightIndex {
    public static let taskDomain = "saltare.tasks"
    public static let documentDomain = "saltare.documents"

    public static func entry(for task: WorkspaceTask) -> SpotlightEntry {
        let description = [task.state, task.priority, task.dueDate.map { "due \($0)" }]
            .compactMap { $0 }
            .joined(separator: " · ")
        let keywords = ["task", task.state] + (task.priority.map { [$0] } ?? [])
        return SpotlightEntry(
            identifier: "saltare://task/\(task.slug)",
            domainIdentifier: taskDomain,
            title: task.title,
            contentDescription: description.isEmpty ? nil : description,
            keywords: keywords
        )
    }

    public static func entry(for document: Document) -> SpotlightEntry {
        SpotlightEntry(
            identifier: "saltare://document/\(document.slug)",
            domainIdentifier: documentDomain,
            title: document.title,
            contentDescription: document.published ? "Published document" : "Draft document",
            keywords: ["document", document.published ? "published" : "draft"]
        )
    }

    public static func taskEntries(_ tasks: [WorkspaceTask]) -> [SpotlightEntry] { tasks.map(entry(for:)) }
    public static func documentEntries(_ documents: [Document]) -> [SpotlightEntry] { documents.map(entry(for:)) }
}
