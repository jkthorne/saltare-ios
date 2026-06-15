import XCTest
@testable import SaltareAgent

final class AnthropicSSEParserTests: XCTestCase {

    /// Feed a scripted event sequence through one parser, collecting all output.
    private func run(_ events: [JSONValue]) -> [LlmStreamEvent] {
        let parser = AnthropicSSEParser()
        return events.flatMap { parser.handle($0) }
    }

    private func ev(_ dict: [String: JSONValue]) -> JSONValue { .object(dict) }

    func testTextTurn() {
        let events = [
            ev(["type": .string("message_start")]),
            ev(["type": .string("content_block_start"), "index": .number(0),
                "content_block": .object(["type": .string("text"), "text": .string("")])]),
            ev(["type": .string("content_block_delta"), "index": .number(0),
                "delta": .object(["type": .string("text_delta"), "text": .string("Hel")])]),
            ev(["type": .string("content_block_delta"), "index": .number(0),
                "delta": .object(["type": .string("text_delta"), "text": .string("lo.")])]),
            ev(["type": .string("content_block_stop"), "index": .number(0)]),
            ev(["type": .string("message_delta"), "delta": .object(["stop_reason": .string("end_turn")])]),
            ev(["type": .string("message_stop")]),
        ]
        XCTAssertEqual(run(events), [
            .textDelta("Hel"),
            .textDelta("lo."),
            .completed(stopReason: .endTurn, assistantBlocks: [.text("Hello.")]),
        ])
    }

    func testToolUseTurnAccumulatesInputJSON() {
        let events = [
            ev(["type": .string("content_block_start"), "index": .number(0),
                "content_block": .object(["type": .string("tool_use"), "id": .string("t1"), "name": .string("phone_call")])]),
            ev(["type": .string("content_block_delta"), "index": .number(0),
                "delta": .object(["type": .string("input_json_delta"), "partial_json": .string("{\"number\":")])]),
            ev(["type": .string("content_block_delta"), "index": .number(0),
                "delta": .object(["type": .string("input_json_delta"), "partial_json": .string("\"123\"}")])]),
            ev(["type": .string("content_block_stop"), "index": .number(0)]),
            ev(["type": .string("message_delta"), "delta": .object(["stop_reason": .string("tool_use")])]),
            ev(["type": .string("message_stop")]),
        ]
        XCTAssertEqual(run(events), [
            .completed(stopReason: .toolUse, assistantBlocks: [
                .toolUse(id: "t1", name: "phone_call", input: ["number": .string("123")]),
            ]),
        ])
    }

    func testThinkingBlockKeepsSignature() {
        let events = [
            ev(["type": .string("content_block_start"), "index": .number(0),
                "content_block": .object(["type": .string("thinking")])]),
            ev(["type": .string("content_block_delta"), "index": .number(0),
                "delta": .object(["type": .string("thinking_delta"), "thinking": .string("reasoning")])]),
            ev(["type": .string("content_block_delta"), "index": .number(0),
                "delta": .object(["type": .string("signature_delta"), "signature": .string("sig123")])]),
            ev(["type": .string("content_block_stop"), "index": .number(0)]),
            ev(["type": .string("message_stop")]),
        ]
        // thinking_delta does not surface as visible text; the signature survives.
        XCTAssertEqual(run(events), [
            .completed(stopReason: .endTurn, assistantBlocks: [.thinking(text: "reasoning", signature: "sig123")]),
        ])
    }

    func testBlocksAssembleInIndexOrder() {
        let events = [
            ev(["type": .string("content_block_start"), "index": .number(0),
                "content_block": .object(["type": .string("thinking")])]),
            ev(["type": .string("content_block_delta"), "index": .number(0),
                "delta": .object(["type": .string("signature_delta"), "signature": .string("s")])]),
            ev(["type": .string("content_block_start"), "index": .number(1),
                "content_block": .object(["type": .string("text"), "text": .string("")])]),
            ev(["type": .string("content_block_delta"), "index": .number(1),
                "delta": .object(["type": .string("text_delta"), "text": .string("Done.")])]),
            ev(["type": .string("message_stop")]),
        ]
        XCTAssertEqual(run(events), [
            .textDelta("Done."),
            .completed(stopReason: .endTurn, assistantBlocks: [
                .thinking(text: "", signature: "s"),
                .text("Done."),
            ]),
        ])
    }

    func testErrorEvent() {
        let events = [
            ev(["type": .string("error"),
                "error": .object(["type": .string("overloaded_error"), "message": .string("Overloaded")])]),
        ]
        XCTAssertEqual(run(events), [.failed(message: "Overloaded", retryable: true)])
    }

    func testDemoClientStreamsACompletion() async {
        var events: [LlmStreamEvent] = []
        for await event in DemoLlmClient().streamTurn(LlmRequest(model: .opus, history: [], tools: [])) {
            events.append(event)
        }
        XCTAssertTrue(events.contains { if case .textDelta = $0 { return true }; return false })
        guard case .completed(.endTurn, let blocks) = events.last else { return XCTFail() }
        XCTAssertEqual(blocks.count, 1)
    }
}
