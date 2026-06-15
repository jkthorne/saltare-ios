import Foundation

/// Resource endpoints wrap their payload in `{ "data": … }`; auth + `me` return
/// the object directly.
public struct DataEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    public let data: T
}

// MARK: - References

public struct WorkspaceRef: Decodable, Sendable, Equatable {
    public let id: Int
    public let slug: String
    public let name: String
    public let plan: String
}

public struct UserRef: Decodable, Sendable, Equatable {
    public let id: Int
    public let email: String
    public let name: String?
    public let emailVerified: Bool?
}

public struct DeviceRef: Decodable, Sendable, Equatable {
    public let id: String?
    public let name: String?
    public let platform: String?
}

public struct ApiKeyRef: Decodable, Sendable, Equatable {
    public let id: Int
    public let name: String?
    public let scopes: [String]
    public let last4: String?
    public let expiresAt: String?
}

/// `{type, id}` polymorphic pointer (User / Agent).
public struct ActorRef: Decodable, Sendable, Equatable {
    public let type: String
    public let id: Int
}

// MARK: - Auth

/// `POST /api/v1/auth/token` and `/auth/refresh` — a workspace-scoped device
/// session (access `sk_sal_` token + rotating `rt_sal_` refresh).
public struct AuthTokens: Decodable, Sendable {
    public let tokenType: String
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: String?
    public let refreshExpiresAt: String?
    public let scopes: [String]
    public let device: DeviceRef
    public let workspace: WorkspaceRef
    public let user: UserRef
    public let agent: Agent
}

/// `GET /api/v1/me`.
public struct CurrentSession: Decodable, Sendable {
    public let workspace: WorkspaceRef
    public let user: UserRef
    public let agent: Agent?
    public let apiKey: ApiKeyRef
}

// MARK: - Resources

public struct Agent: Decodable, Sendable, Identifiable, Equatable {
    public let id: Int
    public let slug: String
    public let name: String
    public let description: String?
    public let status: String
    public let avatarColor: String?
    public let model: String?
    public let createdAt: String
    public let updatedAt: String
}

public struct WorkspaceTask: Decodable, Sendable, Identifiable, Equatable {
    public let id: Int
    public let slug: String
    public let title: String
    public let description: String?
    public let state: String
    public let priority: String?
    public let position: Int?
    public let startDate: String?
    public let dueDate: String?
    public let dueTime: String?
    public let reminderAt: String?
    public let projectId: Int?
    public let parentTaskId: Int?
    public let creatorId: Int?
    public let assignee: ActorRef?
    public let createdAt: String
    public let updatedAt: String
}

public struct Channel: Decodable, Sendable, Identifiable, Equatable {
    public let id: Int
    public let slug: String
    public let name: String?
    public let description: String?
    public let kind: String
    public let archived: Bool
    public let messagesCount: Int?
    public let membersCount: Int?
    public let creatorId: Int?
    public let hostType: String?
    public let hostId: Int?
    public let createdAt: String
    public let updatedAt: String
}

public struct Message: Decodable, Sendable, Identifiable, Equatable {
    public let id: Int
    public let channelId: Int
    public let threadRootMessageId: Int?
    public let body: String?
    public let sender: ActorRef
    public let editedAt: String?
    public let pinnedAt: String?
    public let archivedAt: String?
    public let systemEvent: String?
    public let createdAt: String
    public let updatedAt: String
}

public struct Document: Decodable, Sendable, Identifiable, Equatable {
    public let id: Int
    public let slug: String
    public let title: String
    public let published: Bool
    public let creatorId: Int?
    public let lastEditorId: Int?
    public let createdAt: String
    public let updatedAt: String
    public let body: String?
}
