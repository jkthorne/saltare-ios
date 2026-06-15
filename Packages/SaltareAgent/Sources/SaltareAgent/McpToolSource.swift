import Foundation

/// Maps an MCP `tools/list` result into `ToolSpec`s for the registry. Pure —
/// the network call is injected as `call`. Tool names are prefixed (default
/// `saltare__`) so workspace tools never collide with the local device tools and
/// sort after them (the prompt-cache prefix invariant).
public enum McpToolSource {
    public static let defaultPrefix = "saltare__"

    public static func toolSpecs(
        listResult: JSONValue,
        prefix: String = defaultPrefix,
        call: @escaping @Sendable (_ originalName: String, _ arguments: [String: JSONValue]) async -> ToolOutcome
    ) -> [ToolSpec] {
        (listResult["tools"]?.arrayValue ?? []).compactMap { entry in
            guard let name = entry["name"]?.stringValue else { return nil }
            let schema = entry["inputSchema"] ?? .object([:])
            let properties = schema["properties"]?.objectValue ?? [:]
            let required = (schema["required"]?.arrayValue ?? []).compactMap(\.stringValue)
            return ToolSpec(
                name: prefix + name,
                description: entry["description"]?.stringValue ?? "",
                properties: properties,
                required: required,
                execute: { input in await call(name, input) }
            )
        }
    }

    /// Extract the text + error flag from an MCP `tools/call` result
    /// (`{content:[{type:"text",text}], isError?}`).
    public static func outcome(fromCallResult result: JSONValue) -> ToolOutcome {
        let text = (result["content"]?.arrayValue ?? [])
            .compactMap { $0["text"]?.stringValue }
            .joined(separator: "\n")
        if case .bool(true)? = result["isError"] {
            return .error(text.isEmpty ? "Tool error." : text)
        }
        return .success(text.isEmpty ? "(no output)" : text)
    }
}
