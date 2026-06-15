import XCTest
@testable import SaltareAgent

final class AgentModelTests: XCTestCase {

    func testIdsAreExactApiAliases() {
        XCTAssertEqual(AgentModel.opus.id, "claude-opus-4-8")
        XCTAssertEqual(AgentModel.sonnet.id, "claude-sonnet-4-6")
        XCTAssertEqual(AgentModel.haiku.id, "claude-haiku-4-5")
    }

    func testAdaptiveThinkingOnlyOnOpusAndSonnet() {
        XCTAssertTrue(AgentModel.opus.supportsAdaptiveThinking)
        XCTAssertTrue(AgentModel.sonnet.supportsAdaptiveThinking)
        XCTAssertFalse(AgentModel.haiku.supportsAdaptiveThinking)
    }

    func testCycleWrapsAround() {
        XCTAssertEqual(AgentModel.opus.cycled(), .sonnet)
        XCTAssertEqual(AgentModel.sonnet.cycled(), .haiku)
        XCTAssertEqual(AgentModel.haiku.cycled(), .opus)
    }

    func testFromIdRoundTrips() {
        XCTAssertEqual(AgentModel.from(id: "claude-sonnet-4-6"), .sonnet)
        XCTAssertNil(AgentModel.from(id: "claude-sonnet-4-6-20250101")) // never date-suffixed
        XCTAssertNil(AgentModel.from(id: nil))
    }
}

final class SystemPromptTextTests: XCTestCase {

    func testStableIdentityIsPresentAndPlainText() {
        XCTAssertTrue(SystemPromptText.stable.contains("SALTARE"))
        XCTAssertTrue(SystemPromptText.stable.contains("device_status"))
        XCTAssertFalse(SystemPromptText.stable.contains("#")) // no markdown
    }

    func testVolatileRendersFixedFormat() {
        // A stably-named zone (Foundation normalizes "UTC" to "GMT").
        let zone = TimeZone(identifier: "America/New_York")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let date = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15, hour: 9, minute: 41))!
        let line = SystemPromptText.volatile(
            now: date,
            timeZone: zone,
            locale: Locale(identifier: "en_US"),
            model: .opus
        )
        XCTAssertEqual(line, "Now: 2025-06-15 09:41 (America/New_York). Locale: en-US. Model: claude-opus-4-8.")
    }
}
