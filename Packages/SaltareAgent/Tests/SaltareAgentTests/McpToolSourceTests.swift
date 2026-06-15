import XCTest
@testable import SaltareAgent

final class McpToolSourceTests: XCTestCase {

    private let listResult = JSONValue.parse(#"""
    {"tools":[
      {"name":"create_task","description":"Create a task in the workspace.",
       "inputSchema":{"type":"object","properties":{"title":{"type":"string","description":"Task title"},"priority":{"type":"string","description":"Priority"}},"required":["title"]}},
      {"name":"search_tasks","description":"Search tasks.",
       "inputSchema":{"type":"object","properties":{"query":{"type":"string","description":"Query"}}}}
    ]}
    """#)!

    func testMapsToPrefixedSpecsPreservingSchema() {
        let specs = McpToolSource.toolSpecs(listResult: listResult) { _, _ in .success("ok") }

        XCTAssertEqual(specs.map(\.name), ["saltare__create_task", "saltare__search_tasks"])
        XCTAssertEqual(specs[0].description, "Create a task in the workspace.")
        XCTAssertEqual(specs[0].required, ["title"])
        XCTAssertEqual(Set(specs[0].properties.keys), ["title", "priority"])
        XCTAssertEqual(specs[0].properties["title"], .schema(type: "string", description: "Task title"))
        // No requiredSchema → empty required; MCP tools carry no iOS permission.
        XCTAssertEqual(specs[1].required, [])
        XCTAssertNil(specs[1].requiredPermission)
    }

    func testExecuteForwardsUnprefixedNameToCall() async {
        final class Box: @unchecked Sendable { var name = ""; var args: [String: JSONValue] = [:] }
        let seen = Box()
        let specs = McpToolSource.toolSpecs(listResult: listResult) { name, args in
            seen.name = name
            seen.args = args
            return .success("done")
        }
        let outcome = await specs[0].execute(["title": .string("Ship it")])
        XCTAssertEqual(outcome, .success("done"))
        XCTAssertEqual(seen.name, "create_task") // prefix stripped for the wire call
        XCTAssertEqual(seen.args["title"], .string("Ship it"))
    }

    func testCustomPrefix() {
        let specs = McpToolSource.toolSpecs(listResult: listResult, prefix: "ws_") { _, _ in .success("") }
        XCTAssertEqual(specs.first?.name, "ws_create_task")
    }

    func testIgnoresMalformedEntriesAndEmptyList() {
        let messy = JSONValue.parse(#"{"tools":[{"description":"no name"},{"name":"ok","description":"ok"}]}"#)!
        let specs = McpToolSource.toolSpecs(listResult: messy) { _, _ in .success("") }
        XCTAssertEqual(specs.map(\.name), ["saltare__ok"])

        let none = McpToolSource.toolSpecs(listResult: .object([:])) { _, _ in .success("") }
        XCTAssertTrue(none.isEmpty)
    }

    func testOutcomeFromCallResultJoinsTextContent() {
        let ok = JSONValue.parse(#"{"content":[{"type":"text","text":"line 1"},{"type":"text","text":"line 2"}]}"#)!
        XCTAssertEqual(McpToolSource.outcome(fromCallResult: ok), .success("line 1\nline 2"))

        let err = JSONValue.parse(#"{"content":[{"type":"text","text":"Error: nope"}],"isError":true}"#)!
        XCTAssertEqual(McpToolSource.outcome(fromCallResult: err), .error("Error: nope"))

        let empty = JSONValue.parse(#"{"content":[]}"#)!
        XCTAssertEqual(McpToolSource.outcome(fromCallResult: empty), .success("(no output)"))
    }
}
