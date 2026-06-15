import XCTest
@testable import SaltareWorkspace

final class WorkspaceSnapshotTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: Data(json.utf8))
    }

    private func channels() throws -> [Channel] {
        try decode([Channel].self, #"""
        [{"id":1,"slug":"general","name":"general","kind":"public_channel","archived":false,"messages_count":214,"created_at":"2026-06-01T00:00:00Z","updated_at":"2026-06-14T00:00:00Z"},
         {"id":2,"slug":"engineering","name":"engineering","kind":"public_channel","archived":false,"messages_count":1180,"created_at":"2026-06-01T00:00:00Z","updated_at":"2026-06-14T00:00:00Z"}]
        """#)
    }

    private func tasks() throws -> [WorkspaceTask] {
        try decode([WorkspaceTask].self, #"""
        [{"id":1,"slug":"ship","title":"Ship it","state":"in_progress","due_date":"2026-06-20","created_at":"2026-06-10T00:00:00Z","updated_at":"2026-06-14T00:00:00Z"},
         {"id":2,"slug":"done","title":"Old","state":"completed","created_at":"2026-06-09T00:00:00Z","updated_at":"2026-06-12T00:00:00Z"}]
        """#)
    }

    func testMakeMapsAndFiltersClosedTasks() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = WorkspaceSnapshot.make(workspaceName: "Acme", channels: try channels(), tasks: try tasks(), now: now)

        XCTAssertEqual(snapshot.workspaceName, "Acme")
        XCTAssertEqual(snapshot.channels.map(\.title), ["#general", "#engineering"])
        XCTAssertEqual(snapshot.channels.first?.subtitle, "214 messages")
        XCTAssertEqual(snapshot.channels.first?.id, "saltare://workspace")
        // Completed task filtered out; due date folded into the subtitle.
        XCTAssertEqual(snapshot.tasks.map(\.title), ["Ship it"])
        XCTAssertEqual(snapshot.tasks.first?.subtitle, "in_progress · due 2026-06-20")
        XCTAssertEqual(snapshot.tasks.first?.id, "saltare://task/ship")
        XCTAssertEqual(snapshot.updatedAt, now)
    }

    func testLimit() throws {
        let snapshot = WorkspaceSnapshot.make(workspaceName: "Acme", channels: try channels(), tasks: try tasks(), limit: 1, now: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(snapshot.channels.count, 1)
    }

    func testCodableRoundTrip() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let original = WorkspaceSnapshot.make(workspaceName: "Acme", channels: try channels(), tasks: try tasks(), now: now)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(WorkspaceSnapshot.self, from: encoder.encode(original))
        XCTAssertEqual(restored, original)
    }
}
