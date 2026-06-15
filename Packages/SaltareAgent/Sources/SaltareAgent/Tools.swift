import Foundation

/// The outcome of running one tool. `needsPermission` HOLDS the loop until the
/// UI resolves the grant, then the tool re-executes.
public enum ToolOutcome: Sendable, Equatable {
    case success(String)
    case needsPermission(String)
    case error(String)
}

/// One agent tool. `properties` is a JSON-schema property map
/// (`name -> {"type": "string", "description": …}`); the Anthropic param is
/// built from it in the data layer (iP2.2). The execute closure is `@Sendable`
/// so the spec can cross into the loop's request.
public struct ToolSpec: Sendable {
    public let name: String
    public let description: String
    public let properties: [String: JSONValue]
    public let required: [String]
    /// A runtime permission needed before `execute` can succeed, if any.
    public let requiredPermission: String?
    public let execute: @Sendable ([String: JSONValue]) async -> ToolOutcome

    public init(
        name: String,
        description: String,
        properties: [String: JSONValue] = [:],
        required: [String] = [],
        requiredPermission: String? = nil,
        execute: @escaping @Sendable ([String: JSONValue]) async -> ToolOutcome
    ) {
        self.name = name
        self.description = description
        self.properties = properties
        self.required = required
        self.requiredPermission = requiredPermission
        self.execute = execute
    }
}

/// Executes a named tool — the loop's seam. The concrete runner (iP2.3)
/// pre-checks permissions and dispatches to the registered `ToolSpec`.
public protocol ToolRunner: Sendable {
    func execute(_ name: String, _ input: [String: JSONValue]) async -> ToolOutcome
}
