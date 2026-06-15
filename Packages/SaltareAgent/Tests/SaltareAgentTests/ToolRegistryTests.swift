import XCTest
@testable import SaltareAgent

final class ToolRegistryTests: XCTestCase {

    private func tool(_ name: String, permission: String? = nil, result: ToolOutcome = .success("ok")) -> ToolSpec {
        ToolSpec(name: name, description: name, requiredPermission: permission, execute: { _ in result })
    }

    func testRemoteToolsAppendAfterLocalOrder() {
        let registry = ToolRegistry(localTools: [tool("open_app"), tool("phone_call")])
        registry.remoteTools = [tool("saltare__create_task")]
        XCTAssertEqual(registry.tools.map(\.name), ["open_app", "phone_call", "saltare__create_task"])
        XCTAssertEqual(registry.find("phone_call")?.name, "phone_call")
        XCTAssertNil(registry.find("nope"))
    }

    func testUnknownToolErrors() async {
        let executor = ToolExecutor(registry: ToolRegistry(localTools: []))
        let outcome = await executor.execute("ghost", [:])
        XCTAssertEqual(outcome, .error("Unknown tool: ghost"))
    }

    func testPermissionGateHoldsThenRuns() async {
        let registry = ToolRegistry(localTools: [tool("contacts_search", permission: "contacts", result: .success("2 found"))])

        let denied = ToolExecutor(registry: registry, permissionGranted: { _ in false })
        let deniedOutcome = await denied.execute("contacts_search", [:])
        XCTAssertEqual(deniedOutcome, .needsPermission("contacts"))

        let granted = ToolExecutor(registry: registry, permissionGranted: { _ in true })
        let grantedOutcome = await granted.execute("contacts_search", [:])
        XCTAssertEqual(grantedOutcome, .success("2 found"))
    }

    func testUnpermissionedToolRunsImmediately() async {
        let registry = ToolRegistry(localTools: [tool("phone_call", result: .success("dialer opened"))])
        let executor = ToolExecutor(registry: registry, permissionGranted: { _ in false })
        // No requiredPermission → the gate never trips.
        let outcome = await executor.execute("phone_call", [:])
        XCTAssertEqual(outcome, .success("dialer opened"))
    }

    func testInputAccessors() {
        let input: [String: JSONValue] = ["number": .string("123"), "days": .number(7)]
        XCTAssertEqual(input.str("number"), "123")
        XCTAssertEqual(input.int("days"), 7)
        XCTAssertEqual(input.str("missing"), "")
        XCTAssertNil(input.int("number"))
    }
}
