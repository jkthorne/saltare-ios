import XCTest
@testable import SaltareAgent

final class AgentActivityPresentationTests: XCTestCase {
    func testStreamingShowsRunningToolOrWorking() {
        let withTool = AgentActivityPresentation.snapshot(phase: .streaming, toolCount: 1, lastTool: "contacts_search")
        XCTAssertEqual(withTool.statusLabel, "THINKING")
        XCTAssertEqual(withTool.detail, "Running contacts_search")
        XCTAssertTrue(withTool.isActive)

        let noTool = AgentActivityPresentation.snapshot(phase: .streaming, toolCount: 0, lastTool: nil)
        XCTAssertEqual(noTool.detail, "Working…")
    }

    func testPermissionAndError() {
        let perm = AgentActivityPresentation.snapshot(phase: .awaitingPermission, toolCount: 2, lastTool: "calendar")
        XCTAssertEqual(perm.statusLabel, "PERMISSION")
        XCTAssertEqual(perm.detail, "Allow calendar?")
        XCTAssertTrue(perm.isActive)

        let error = AgentActivityPresentation.snapshot(phase: .error, toolCount: 0, lastTool: nil)
        XCTAssertEqual(error.statusLabel, "ERROR")
        XCTAssertFalse(error.isActive)
    }

    func testIdlePluralizesToolCount() {
        XCTAssertEqual(AgentActivityPresentation.snapshot(phase: .idle, toolCount: 1, lastTool: nil).detail, "1 tool")
        XCTAssertEqual(AgentActivityPresentation.snapshot(phase: .idle, toolCount: 3, lastTool: nil).detail, "3 tools")
        XCTAssertEqual(AgentActivityPresentation.snapshot(phase: .idle, toolCount: 0, lastTool: nil).detail, "Complete")
        XCTAssertFalse(AgentActivityPresentation.snapshot(phase: .idle, toolCount: 0, lastTool: nil).isActive)
    }
}
