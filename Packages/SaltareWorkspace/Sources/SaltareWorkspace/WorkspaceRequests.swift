import Foundation

/// A transport-agnostic description of one API call. Built by `WorkspaceEndpoint`
/// and turned into a `URLRequest` by `WorkspaceClient` — kept separate so the
/// endpoint shapes are unit-testable without a network.
public struct WorkspaceRequest: Equatable, Sendable {
    public let method: String
    public let path: String           // e.g. "api/v1/tasks"
    public let query: [String: String]
    public let body: Data?
    public let requiresAuth: Bool

    public init(method: String, path: String, query: [String: String] = [:], body: Data? = nil, requiresAuth: Bool = true) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
        self.requiresAuth = requiresAuth
    }
}

// MARK: - Request bodies (snake_cased on the wire)

struct TaskCreate: Encodable {
    var title: String
    var description: String?
    var state: String?
    var priority: String?
    var dueDate: String?
    var startDate: String?
}
private struct TaskEnvelope: Encodable { let task: TaskCreate }
private struct MessageEnvelope: Encodable {
    struct Body: Encodable { let channelId: Int; let body: String }
    let message: Body
}
private struct AgentMessageBody: Encodable { let content: String }
private struct TokenRequestBody: Encodable {
    let emailAddress: String
    let password: String
    let deviceId: String?
    let deviceName: String?
    let platform: String?
    let workspaceSlug: String?
}
private struct RefreshBody: Encodable { let refreshToken: String }

// MARK: - Endpoints

public enum WorkspaceEndpoint {

    // Auth (token/refresh skip the bearer gate)
    public static func token(email: String, password: String, deviceId: String? = nil, deviceName: String? = nil, platform: String? = "ios", workspaceSlug: String? = nil) -> WorkspaceRequest {
        WorkspaceRequest(method: "POST", path: "api/v1/auth/token",
                         body: encode(TokenRequestBody(emailAddress: email, password: password, deviceId: deviceId, deviceName: deviceName, platform: platform, workspaceSlug: workspaceSlug)),
                         requiresAuth: false)
    }
    public static func refresh(refreshToken: String) -> WorkspaceRequest {
        WorkspaceRequest(method: "POST", path: "api/v1/auth/refresh", body: encode(RefreshBody(refreshToken: refreshToken)), requiresAuth: false)
    }
    public static func signOut() -> WorkspaceRequest {
        WorkspaceRequest(method: "DELETE", path: "api/v1/auth/token")
    }
    public static func me() -> WorkspaceRequest {
        WorkspaceRequest(method: "GET", path: "api/v1/me")
    }

    // Tasks
    public static func tasks(state: String? = nil, projectId: Int? = nil, page: Int? = nil) -> WorkspaceRequest {
        var query: [String: String] = [:]
        if let state { query["state"] = state }
        if let projectId { query["project_id"] = String(projectId) }
        if let page { query["page"] = String(page) }
        return WorkspaceRequest(method: "GET", path: "api/v1/tasks", query: query)
    }
    public static func task(slug: String) -> WorkspaceRequest {
        WorkspaceRequest(method: "GET", path: "api/v1/tasks/\(slug)")
    }
    public static func createTask(title: String, description: String? = nil, dueDate: String? = nil) -> WorkspaceRequest {
        WorkspaceRequest(method: "POST", path: "api/v1/tasks",
                         body: encode(TaskEnvelope(task: TaskCreate(title: title, description: description, state: nil, priority: nil, dueDate: dueDate, startDate: nil))))
    }

    // Channels & messages
    public static func channels(page: Int? = nil) -> WorkspaceRequest {
        WorkspaceRequest(method: "GET", path: "api/v1/channels", query: page.map { ["page": String($0)] } ?? [:])
    }
    public static func messages(channelId: Int, page: Int? = nil) -> WorkspaceRequest {
        var query = ["channel_id": String(channelId)]
        if let page { query["page"] = String(page) }
        return WorkspaceRequest(method: "GET", path: "api/v1/messages", query: query)
    }
    public static func sendMessage(channelId: Int, body: String) -> WorkspaceRequest {
        WorkspaceRequest(method: "POST", path: "api/v1/messages",
                         body: encode(MessageEnvelope(message: .init(channelId: channelId, body: body))))
    }

    // Agents
    public static func agents(page: Int? = nil) -> WorkspaceRequest {
        WorkspaceRequest(method: "GET", path: "api/v1/agents", query: page.map { ["page": String($0)] } ?? [:])
    }
    public static func agent(slug: String) -> WorkspaceRequest {
        WorkspaceRequest(method: "GET", path: "api/v1/agents/\(slug)")
    }
    public static func messageAgent(slug: String, content: String) -> WorkspaceRequest {
        WorkspaceRequest(method: "POST", path: "api/v1/agents/\(slug)/message", body: encode(AgentMessageBody(content: content)))
    }

    // Documents
    public static func documents(page: Int? = nil) -> WorkspaceRequest {
        WorkspaceRequest(method: "GET", path: "api/v1/documents", query: page.map { ["page": String($0)] } ?? [:])
    }
    public static func document(slug: String) -> WorkspaceRequest {
        WorkspaceRequest(method: "GET", path: "api/v1/documents/\(slug)")
    }

    /// JSON body encoder (camelCase → snake_case to match Rails params).
    static func encode<T: Encodable>(_ value: T) -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return (try? encoder.encode(value)) ?? Data()
    }
}
