import XCTest
@testable import SaltareAgent

final class AnthropicRequestTests: XCTestCase {

    private let tool = ToolSpec(
        name: "phone_call",
        description: "Open the dialer.",
        properties: ["number": .schema(type: "string", description: "E.164 number")],
        required: ["number"],
        execute: { _ in .success("ok") }
    )

    func testCoreEnvelope() {
        let body = AnthropicRequest.body(
            model: .opus,
            history: [.user("hi")],
            tools: [],
            systemStable: "STABLE",
            systemVolatile: "VOLATILE"
        )
        XCTAssertEqual(body["model"], .string("claude-opus-4-8"))
        XCTAssertEqual(body["stream"], .bool(true))
        XCTAssertEqual(body["max_tokens"], .number(4096))
        XCTAssertEqual(body["messages"], .array([.object(["role": .string("user"), "content": .string("hi")])]))
    }

    func testSystemHasCacheBreakpointOnStableBlockOnly() {
        let body = AnthropicRequest.body(model: .opus, history: [], tools: [], systemStable: "S", systemVolatile: "V")
        let system = body["system"]?.arrayValue
        XCTAssertEqual(system?.count, 2)
        XCTAssertEqual(system?[0], .object([
            "type": .string("text"), "text": .string("S"),
            "cache_control": .object(["type": .string("ephemeral")]),
        ]))
        XCTAssertEqual(system?[1], .object(["type": .string("text"), "text": .string("V")]))
    }

    func testAdaptiveThinkingOnlyForOpusAndSonnet() {
        XCTAssertEqual(AnthropicRequest.body(model: .opus, history: [], tools: [], systemStable: "", systemVolatile: "")["thinking"],
                       .object(["type": .string("adaptive")]))
        XCTAssertEqual(AnthropicRequest.body(model: .sonnet, history: [], tools: [], systemStable: "", systemVolatile: "")["thinking"],
                       .object(["type": .string("adaptive")]))
        XCTAssertNil(AnthropicRequest.body(model: .haiku, history: [], tools: [], systemStable: "", systemVolatile: "")["thinking"])
    }

    func testToolsCarryInputSchema() {
        let body = AnthropicRequest.body(model: .opus, history: [], tools: [tool], systemStable: "", systemVolatile: "")
        XCTAssertEqual(body["tools"], .array([
            .object([
                "name": .string("phone_call"),
                "description": .string("Open the dialer."),
                "input_schema": .object([
                    "type": .string("object"),
                    "properties": .object(["number": .schema(type: "string", description: "E.164 number")]),
                    "required": .array([.string("number")]),
                ]),
            ]),
        ]))
        // No tools → key omitted entirely (keeps the cache prefix clean).
        XCTAssertNil(AnthropicRequest.body(model: .opus, history: [], tools: [], systemStable: "", systemVolatile: "")["tools"])
    }

    func testAssistantAndToolResultMessages() {
        let history: [HistoryMessage] = [
            .assistant([
                .thinking(text: "hmm", signature: "sig"),
                .toolUse(id: "t1", name: "phone_call", input: ["number": .string("1")]),
            ]),
            .toolResults([ToolResult(toolUseId: "t1", text: "Opened dialer", isError: false)]),
        ]
        let body = AnthropicRequest.body(model: .opus, history: history, tools: [], systemStable: "", systemVolatile: "")
        let messages = body["messages"]?.arrayValue

        XCTAssertEqual(messages?[0], .object([
            "role": .string("assistant"),
            "content": .array([
                .object(["type": .string("thinking"), "thinking": .string("hmm"), "signature": .string("sig")]),
                .object([
                    "type": .string("tool_use"), "id": .string("t1"),
                    "name": .string("phone_call"), "input": .object(["number": .string("1")]),
                ]),
            ]),
        ]))
        XCTAssertEqual(messages?[1], .object([
            "role": .string("user"),
            "content": .array([
                .object([
                    "type": .string("tool_result"),
                    "tool_use_id": .string("t1"),
                    "content": .string("Opened dialer"),
                    "is_error": .bool(false),
                ]),
            ]),
        ]))
    }

    func testBodyEncodesToJSON() throws {
        let body = AnthropicRequest.body(model: .opus, history: [.user("hi")], tools: [], systemStable: "S", systemVolatile: "V")
        let data = try body.serializedData()
        // Round-trips and renders max_tokens as an integer (not 4096.0).
        XCTAssertEqual(JSONValue.parse(data)?["max_tokens"], .number(4096))
        XCTAssertTrue(String(data: data, encoding: .utf8)!.contains("\"max_tokens\":4096"))
    }
}
