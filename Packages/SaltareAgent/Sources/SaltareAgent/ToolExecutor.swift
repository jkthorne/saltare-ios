import Foundation

/// Dispatches tool calls by name with a runtime-permission pre-check (the
/// Android `ToolExecutor`). `permissionGranted` is injected by the app — it
/// reads the platform authorization status (Contacts/Calendar/Location). A
/// not-yet-granted permission returns `.needsPermission`, which the loop holds
/// on until the UI resolves the GRANT, then re-executes.
public struct ToolExecutor: ToolRunner {
    private let registry: ToolRegistry
    private let permissionGranted: @Sendable (String) -> Bool

    public init(registry: ToolRegistry, permissionGranted: @escaping @Sendable (String) -> Bool = { _ in true }) {
        self.registry = registry
        self.permissionGranted = permissionGranted
    }

    public func execute(_ name: String, _ input: [String: JSONValue]) async -> ToolOutcome {
        guard let spec = registry.find(name) else { return .error("Unknown tool: \(name)") }
        if let permission = spec.requiredPermission, !permissionGranted(permission) {
            return .needsPermission(permission)
        }
        return await spec.execute(input)
    }
}

/// Convenience accessors for tool inputs (the Android `Map.str` / `Map.int`).
public extension Dictionary where Key == String, Value == JSONValue {
    func str(_ key: String) -> String { self[key]?.stringValue ?? "" }
    func int(_ key: String) -> Int? { self[key]?.intValue }
    func double(_ key: String) -> Double? { self[key]?.numberValue }
}
