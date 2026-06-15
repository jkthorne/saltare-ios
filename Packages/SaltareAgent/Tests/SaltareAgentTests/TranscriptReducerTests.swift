import XCTest
@testable import SaltareAgent

/// Ported from the Android `:agent` `TranscriptReducerTest`.
final class TranscriptReducerTests: XCTestCase {

    private func reduce(_ events: [AgentEvent], from start: [ChatMessage] = []) -> [ChatMessage] {
        events.reduce(start) { TranscriptReducer.reduce($0, $1) }
    }

    func testTextDeltasAppendToOneStreamingMessage() {
        let result = reduce([.textDelta("Hel"), .textDelta("lo.")])
        XCTAssertEqual(result, [.agentText(text: "Hello.", streaming: true)])
    }

    func testTurnCompleteSealsTheStreamingMessage() {
        let result = reduce([.textDelta("Done."), .turnComplete])
        XCTAssertEqual(result, [.agentText(text: "Done.", streaming: false)])
    }

    func testToolCallSealsTextThenAddsRunningChip() {
        let result = reduce([
            .textDelta("Calling…"),
            .toolCallStarted(id: "t1", name: "phone_call", input: [:]),
        ])
        XCTAssertEqual(result, [
            .agentText(text: "Calling…", streaming: false),
            .toolChip(id: "t1", name: "phone_call", status: .running),
        ])
    }

    func testToolResultRewritesChipById() {
        let base = reduce([.toolCallStarted(id: "t1", name: "phone_call", input: [:])])
        XCTAssertEqual(
            TranscriptReducer.reduce(base, .toolResultReady(id: "t1", name: "phone_call", outcome: .success("Dialer opened"))),
            [.toolChip(id: "t1", name: "phone_call", status: .done("Dialer opened"))]
        )
        XCTAssertEqual(
            TranscriptReducer.reduce(base, .toolResultReady(id: "t1", name: "phone_call", outcome: .needsPermission("contacts"))),
            [.toolChip(id: "t1", name: "phone_call", status: .needsPermission("contacts"))]
        )
        XCTAssertEqual(
            TranscriptReducer.reduce(base, .toolResultReady(id: "t1", name: "phone_call", outcome: .error("boom"))),
            [.toolChip(id: "t1", name: "phone_call", status: .failed("boom"))]
        )
    }

    func testTextAfterAToolChipStartsANewMessage() {
        let result = reduce([
            .toolCallStarted(id: "t1", name: "a", input: [:]),
            .textDelta("After tool."),
        ])
        XCTAssertEqual(result, [
            .toolChip(id: "t1", name: "a", status: .running),
            .agentText(text: "After tool.", streaming: true),
        ])
    }

    func testSealAllSealsTheLiveMessage() {
        XCTAssertEqual(
            TranscriptReducer.sealAll([.agentText(text: "partial", streaming: true)]),
            [.agentText(text: "partial", streaming: false)]
        )
    }
}
