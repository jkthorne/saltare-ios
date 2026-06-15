import Foundation
import SaltareWorkspace

/// Async load state for a workspace surface.
enum Loadable<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? { if case let .loaded(value) = self { return value }; return nil }
    var isLoading: Bool { if case .loading = self { return true }; return false }
}

/// Friendly text for a `WorkspaceError` (shared by sign-in + the surfaces).
func workspaceErrorText(_ error: Error) -> String {
    guard let error = error as? WorkspaceError else { return error.localizedDescription }
    switch error {
    case let .api(_, message, _): return message
    case .notAuthenticated: return "Not signed in."
    case let .http(status): return "Server error (HTTP \(status))."
    case let .transport(message): return "Network error: \(message)"
    case .decoding: return "Unexpected response from the server."
    }
}
