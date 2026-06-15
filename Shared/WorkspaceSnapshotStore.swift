import Foundation
import SaltareWorkspace

/// Reads/writes the `WorkspaceSnapshot` in the shared App Group container — the
/// app writes it when workspace data loads; the workspace Widget reads it. A
/// no-op when the App Group container isn't available (e.g. unsigned simulator
/// builds), so callers never need to branch.
enum WorkspaceSnapshotStore {
    static let appGroup = "group.ai.saltare.app"
    private static let fileName = "workspace-snapshot.json"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func save(_ snapshot: WorkspaceSnapshot) {
        guard let fileURL, let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func load() -> WorkspaceSnapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(WorkspaceSnapshot.self, from: data)
    }

    static func clear() {
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
