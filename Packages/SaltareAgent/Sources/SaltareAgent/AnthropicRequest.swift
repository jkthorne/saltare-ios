import Foundation

/// Builds the Anthropic Messages API request body (`POST /v1/messages`) from an
/// `LlmRequest`. Pure — the testable param-assembly seam (the Android
/// `RequestBuilder` analog).
///
/// Cache discipline: render order is tools → system → messages, so the stable
/// system block carries `cache_control: {type: "ephemeral"}` and the volatile
/// suffix renders after it. Tool list order IS the cache prefix — never reorder.
public enum AnthropicRequest {
    public static let defaultMaxTokens = 4096

    public static func body(
        model: AgentModel,
        history: [HistoryMessage],
        tools: [ToolSpec],
        systemStable: String,
        systemVolatile: String,
        maxTokens: Int = defaultMaxTokens
    ) -> JSONValue {
        var root: [String: JSONValue] = [
            "model": .string(model.id),
            "max_tokens": .number(Double(maxTokens)),
            "stream": .bool(true),
            "system": .array([
                .object([
                    "type": .string("text"),
                    "text": .string(systemStable),
                    "cache_control": .object(["type": .string("ephemeral")]),
                ]),
                .object(["type": .string("text"), "text": .string(systemVolatile)]),
            ]),
            "messages": .array(history.map(messageJSON)),
        ]
        if !tools.isEmpty {
            root["tools"] = .array(tools.map(toolJSON))
        }
        // Adaptive thinking on Opus/Sonnet; omitted on Haiku (budget_tokens 400s).
        if model.supportsAdaptiveThinking {
            root["thinking"] = .object(["type": .string("adaptive")])
        }
        return .object(root)
    }

    static func messageJSON(_ message: HistoryMessage) -> JSONValue {
        switch message {
        case let .user(text):
            return .object(["role": .string("user"), "content": .string(text)])
        case let .assistant(blocks):
            return .object(["role": .string("assistant"), "content": .array(blocks.map(blockJSON))])
        case let .toolResults(results):
            return .object([
                "role": .string("user"),
                "content": .array(results.map { result in
                    .object([
                        "type": .string("tool_result"),
                        "tool_use_id": .string(result.toolUseId),
                        "content": .string(result.text),
                        "is_error": .bool(result.isError),
                    ])
                }),
            ])
        }
    }

    static func blockJSON(_ block: AssistantBlock) -> JSONValue {
        switch block {
        case let .text(text):
            return .object(["type": .string("text"), "text": .string(text)])
        case let .toolUse(id, name, input):
            return .object([
                "type": .string("tool_use"),
                "id": .string(id),
                "name": .string(name),
                "input": .object(input),
            ])
        case let .thinking(text, signature):
            // signature MUST be echoed untouched or the next request 400s.
            return .object([
                "type": .string("thinking"),
                "thinking": .string(text),
                "signature": .string(signature),
            ])
        case let .redactedThinking(data):
            return .object(["type": .string("redacted_thinking"), "data": .string(data)])
        }
    }

    static func toolJSON(_ tool: ToolSpec) -> JSONValue {
        .object([
            "name": .string(tool.name),
            "description": .string(tool.description),
            "input_schema": .object([
                "type": .string("object"),
                "properties": .object(tool.properties),
                "required": .array(tool.required.map(JSONValue.string)),
            ]),
        ])
    }
}
