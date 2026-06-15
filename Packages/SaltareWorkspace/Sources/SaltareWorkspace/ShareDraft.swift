import Foundation

/// A draft built from shared content (text and/or a URL) — the Share extension
/// turns it into a task (title + description) or a channel message (body). Pure
/// + tested so the extension UI stays a thin shell.
public struct ShareDraft: Equatable, Sendable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }

    /// Title = the first non-empty line (or the URL's host); body = the text with
    /// the URL appended if it isn't already present.
    public static func from(text: String?, url: String?) -> ShareDraft {
        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = url?.trimmingCharacters(in: .whitespacesAndNewlines)

        let firstLine = trimmedText?
            .split(whereSeparator: \.isNewline)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .flatMap { $0.isEmpty ? nil : $0 }

        let title = firstLine
            ?? url.flatMap { URLComponents(string: $0)?.host }
            ?? url
            ?? "Shared"

        var parts: [String] = []
        if let trimmedText, !trimmedText.isEmpty { parts.append(trimmedText) }
        if let url, !url.isEmpty, trimmedText?.contains(url) != true { parts.append(url) }

        return ShareDraft(title: String(title.prefix(120)), body: parts.joined(separator: "\n"))
    }
}
