import Foundation

/// The `{ "error": { "code", "message" } }` envelope every endpoint returns on
/// failure (plus optional extra keys, ignored here).
public struct ApiErrorBody: Decodable, Sendable {
    public struct Detail: Decodable, Sendable {
        public let code: String
        public let message: String
    }
    public let error: Detail
}

public enum WorkspaceError: Error, Sendable, Equatable {
    /// A structured `{error:{code,message}}` from the server.
    case api(code: String, message: String, status: Int)
    /// A non-2xx with no decodable error body.
    case http(status: Int)
    /// No access token available (sign in first).
    case notAuthenticated
    case transport(String)
    case decoding(String)
}
