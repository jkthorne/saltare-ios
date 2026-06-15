import Foundation

/// A `Sendable`, `Equatable` JSON value — the Swift stand-in for the Android
/// agent's `Map<String, Any?>` tool inputs/schemas. Using a closed value type
/// (rather than `Any`) keeps tool inputs sendable across the loop's tasks and
/// trivially encodable for the Anthropic request (iP2.2).
public enum JSONValue: Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    public var stringValue: String? { if case let .string(s) = self { return s }; return nil }
    public var numberValue: Double? { if case let .number(n) = self { return n }; return nil }
    public var boolValue: Bool? { if case let .bool(b) = self { return b }; return nil }
    public var objectValue: [String: JSONValue]? { if case let .object(o) = self { return o }; return nil }
    public var arrayValue: [JSONValue]? { if case let .array(a) = self { return a }; return nil }
}

public extension JSONValue {
    /// Convenience for building tool schemas: `.schema(type: "string", description: …)`.
    static func schema(type: String, description: String) -> JSONValue {
        .object(["type": .string(type), "description": .string(description)])
    }
}
