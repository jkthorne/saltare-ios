import Foundation

/// Accumulates Anthropic Messages SSE events into `LlmStreamEvent`s. One parser
/// per request (confined to that request's task — not Sendable). Text deltas
/// emit immediately; the full assistant content (text, tool_use, thinking +
/// signature) assembles at `message_stop`.
final class AnthropicSSEParser {

    private struct Block {
        var type: String
        var text = ""
        var toolId = ""
        var toolName = ""
        var toolJSON = ""
        var thinking = ""
        var signature = ""
        var redactedData = ""
    }

    private var blocks: [Int: Block] = [:]
    private var order: [Int] = []
    private var stopReason: StopReason = .endTurn

    func handle(_ event: JSONValue) -> [LlmStreamEvent] {
        guard let type = event["type"]?.stringValue else { return [] }
        switch type {
        case "message_start":
            blocks.removeAll(); order.removeAll(); stopReason = .endTurn
            return []

        case "content_block_start":
            guard let index = event["index"]?.intValue, let cb = event["content_block"] else { return [] }
            var block = Block(type: cb["type"]?.stringValue ?? "")
            switch block.type {
            case "tool_use":
                block.toolId = cb["id"]?.stringValue ?? ""
                block.toolName = cb["name"]?.stringValue ?? ""
            case "redacted_thinking":
                block.redactedData = cb["data"]?.stringValue ?? ""
            default:
                break
            }
            blocks[index] = block
            order.append(index)
            return []

        case "content_block_delta":
            guard let index = event["index"]?.intValue, let delta = event["delta"], var block = blocks[index] else { return [] }
            switch delta["type"]?.stringValue {
            case "text_delta":
                let text = delta["text"]?.stringValue ?? ""
                block.text += text; blocks[index] = block
                return text.isEmpty ? [] : [.textDelta(text)]
            case "input_json_delta":
                block.toolJSON += delta["partial_json"]?.stringValue ?? ""; blocks[index] = block
                return []
            case "thinking_delta":
                block.thinking += delta["thinking"]?.stringValue ?? ""; blocks[index] = block
                return []
            case "signature_delta":
                block.signature += delta["signature"]?.stringValue ?? ""; blocks[index] = block
                return []
            default:
                return []
            }

        case "content_block_stop":
            return []

        case "message_delta":
            if let reason = event["delta"]?["stop_reason"]?.stringValue {
                stopReason = Self.mapStop(reason)
            }
            return []

        case "message_stop":
            let assembled = order.compactMap { blocks[$0] }.compactMap(Self.assistantBlock)
            return [.completed(stopReason: stopReason, assistantBlocks: assembled)]

        case "error":
            let message = event["error"]?["message"]?.stringValue ?? "stream error"
            let kind = event["error"]?["type"]?.stringValue ?? ""
            let retryable = kind == "overloaded_error" || kind == "api_error"
            return [.failed(message: message, retryable: retryable)]

        default:
            return [] // ping, etc.
        }
    }

    private static func assistantBlock(_ block: Block) -> AssistantBlock? {
        switch block.type {
        case "text":
            return .text(block.text)
        case "tool_use":
            let input = JSONValue.parse(block.toolJSON.isEmpty ? "{}" : block.toolJSON)?.objectValue ?? [:]
            return .toolUse(id: block.toolId, name: block.toolName, input: input)
        case "thinking":
            return .thinking(text: block.thinking, signature: block.signature)
        case "redacted_thinking":
            return .redactedThinking(data: block.redactedData)
        default:
            return nil
        }
    }

    private static func mapStop(_ reason: String) -> StopReason {
        switch reason {
        case "end_turn": .endTurn
        case "tool_use": .toolUse
        case "max_tokens": .maxTokens
        case "refusal": .refusal
        default: .other
        }
    }
}
