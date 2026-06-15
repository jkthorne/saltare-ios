import XCTest
@testable import SaltareWorkspace

final class SpotlightIndexTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: Data(json.utf8))
    }

    func testTaskEntry() throws {
        let task = try decode(WorkspaceTask.self, #"""
        {"id":7,"slug":"ship-ios","title":"Ship the iOS app","state":"in_progress","priority":"high","due_date":"2026-06-20","created_at":"2026-06-10T00:00:00Z","updated_at":"2026-06-14T00:00:00Z"}
        """#)
        let entry = SpotlightIndex.entry(for: task)
        XCTAssertEqual(entry.identifier, "saltare://task/ship-ios")
        XCTAssertEqual(entry.domainIdentifier, SpotlightIndex.taskDomain)
        XCTAssertEqual(entry.title, "Ship the iOS app")
        XCTAssertEqual(entry.contentDescription, "in_progress · high · due 2026-06-20")
        XCTAssertEqual(entry.keywords, ["task", "in_progress", "high"])
    }

    func testTaskEntryWithoutPriorityOrDue() throws {
        let task = try decode(WorkspaceTask.self, #"""
        {"id":8,"slug":"mcp","title":"Wire MCP","state":"open","created_at":"2026-06-11T00:00:00Z","updated_at":"2026-06-14T00:00:00Z"}
        """#)
        let entry = SpotlightIndex.entry(for: task)
        XCTAssertEqual(entry.contentDescription, "open")
        XCTAssertEqual(entry.keywords, ["task", "open"])
    }

    func testDocumentEntry() throws {
        let doc = try decode(Document.self, #"""
        {"id":1,"slug":"roadmap","title":"saltare-ios roadmap","published":true,"created_at":"2026-06-14T00:00:00Z","updated_at":"2026-06-15T00:00:00Z"}
        """#)
        let entry = SpotlightIndex.entry(for: doc)
        XCTAssertEqual(entry.identifier, "saltare://document/roadmap")
        XCTAssertEqual(entry.domainIdentifier, SpotlightIndex.documentDomain)
        XCTAssertEqual(entry.contentDescription, "Published document")
        XCTAssertEqual(entry.keywords, ["document", "published"])

        let draft = try decode(Document.self, #"""
        {"id":2,"slug":"notes","title":"Notes","published":false,"created_at":"2026-06-13T00:00:00Z","updated_at":"2026-06-14T00:00:00Z"}
        """#)
        XCTAssertEqual(SpotlightIndex.entry(for: draft).contentDescription, "Draft document")
        XCTAssertEqual(SpotlightIndex.entry(for: draft).keywords, ["document", "draft"])
    }

    func testCollectionHelpers() throws {
        let task = try decode(WorkspaceTask.self, #"""
        {"id":8,"slug":"a","title":"A","state":"open","created_at":"2026-06-11T00:00:00Z","updated_at":"2026-06-14T00:00:00Z"}
        """#)
        let doc = try decode(Document.self, #"""
        {"id":1,"slug":"b","title":"B","published":true,"created_at":"2026-06-14T00:00:00Z","updated_at":"2026-06-15T00:00:00Z"}
        """#)
        XCTAssertEqual(SpotlightIndex.taskEntries([task]).map(\.identifier), ["saltare://task/a"])
        XCTAssertEqual(SpotlightIndex.documentEntries([doc]).map(\.identifier), ["saltare://document/b"])
    }
}
