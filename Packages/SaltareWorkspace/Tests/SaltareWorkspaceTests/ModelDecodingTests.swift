import XCTest
@testable import SaltareWorkspace

/// Decodes the exact JSON the saltare `Api::V1::*Serializer`s emit.
final class ModelDecodingTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d
    }()

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try decoder.decode(type, from: Data(json.utf8))
    }

    func testAuthTokens() throws {
        let json = """
        {"token_type":"Bearer","access_token":"sk_sal_abc","refresh_token":"rt_sal_xyz",
         "expires_at":"2026-07-15T00:00:00.000Z","refresh_expires_at":"2026-09-15T00:00:00.000Z",
         "scopes":["*"],"device":{"id":"dev1","name":"Jack's iPhone","platform":"ios"},
         "workspace":{"id":1,"slug":"acme","name":"Acme","plan":"pro"},
         "user":{"id":2,"email":"a@b.co","name":"Jack","email_verified":true},
         "agent":{"id":3,"slug":"saltare","name":"Saltare","description":null,"status":"active",
                  "avatar_color":"#00C8F0","model":"claude-opus-4-8",
                  "created_at":"2026-06-01T00:00:00.000Z","updated_at":"2026-06-01T00:00:00.000Z"}}
        """
        let tokens = try decode(AuthTokens.self, json)
        XCTAssertEqual(tokens.accessToken, "sk_sal_abc")
        XCTAssertEqual(tokens.refreshToken, "rt_sal_xyz")
        XCTAssertEqual(tokens.workspace.slug, "acme")
        XCTAssertEqual(tokens.user.emailVerified, true)
        XCTAssertEqual(tokens.agent.model, "claude-opus-4-8")
        XCTAssertEqual(tokens.scopes, ["*"])
    }

    func testCurrentSessionWithNullAgent() throws {
        let json = """
        {"workspace":{"id":1,"slug":"acme","name":"Acme","plan":"pro"},
         "user":{"id":2,"email":"a@b.co","name":"Jack"},
         "agent":null,
         "api_key":{"id":5,"name":"iPhone","scopes":["tasks:read","mcp:tools:read"],"last4":"ab12","expires_at":null}}
        """
        let session = try decode(CurrentSession.self, json)
        XCTAssertNil(session.agent)
        XCTAssertEqual(session.apiKey.scopes, ["tasks:read", "mcp:tools:read"])
        XCTAssertNil(session.user.emailVerified)
    }

    func testTaskEnvelopeWithAssigneeAndDueTime() throws {
        let json = """
        {"data":[{"id":10,"slug":"ship-it","title":"Ship it","description":"now","state":"open",
                  "priority":"high","position":1,"start_date":"2026-06-15","due_date":"2026-06-20",
                  "due_time":"14:30","reminder_at":null,"project_id":7,"parent_task_id":null,
                  "creator_id":2,"assignee":{"type":"Agent","id":3},
                  "created_at":"2026-06-15T00:00:00.000Z","updated_at":"2026-06-15T00:00:00.000Z"}]}
        """
        let tasks = try decode(DataEnvelope<[WorkspaceTask]>.self, json).data
        let task = try XCTUnwrap(tasks.first)
        XCTAssertEqual(task.title, "Ship it")
        XCTAssertEqual(task.state, "open")
        XCTAssertEqual(task.dueTime, "14:30")
        XCTAssertEqual(task.assignee, ActorRef(type: "Agent", id: 3))
        XCTAssertEqual(task.projectId, 7)
    }

    func testMessageAndChannelAndAgentAndDocument() throws {
        let message = try decode(DataEnvelope<Message>.self, """
        {"data":{"id":1,"channel_id":4,"thread_root_message_id":null,"body":"hello",
                 "sender":{"type":"User","id":2},"edited_at":null,"pinned_at":null,
                 "archived_at":null,"system_event":null,
                 "created_at":"2026-06-15T00:00:00Z","updated_at":"2026-06-15T00:00:00Z"}}
        """).data
        XCTAssertEqual(message.body, "hello")
        XCTAssertEqual(message.sender, ActorRef(type: "User", id: 2))

        let channel = try decode(DataEnvelope<Channel>.self, """
        {"data":{"id":4,"slug":"general","name":"General","description":null,"kind":"public_channel",
                 "archived":false,"messages_count":12,"members_count":3,"creator_id":2,
                 "host_type":null,"host_id":null,
                 "created_at":"2026-06-15T00:00:00Z","updated_at":"2026-06-15T00:00:00Z"}}
        """).data
        XCTAssertEqual(channel.kind, "public_channel")
        XCTAssertFalse(channel.archived)
        XCTAssertEqual(channel.messagesCount, 12)

        let document = try decode(DataEnvelope<Document>.self, """
        {"data":{"id":8,"slug":"spec","title":"Spec","published":true,"creator_id":2,
                 "last_editor_id":2,"created_at":"2026-06-15T00:00:00Z","updated_at":"2026-06-15T00:00:00Z",
                 "body":"# Heading"}}
        """).data
        XCTAssertTrue(document.published)
        XCTAssertEqual(document.body, "# Heading")
    }

    func testApiErrorEnvelope() throws {
        let error = try decode(ApiErrorBody.self, """
        {"error":{"code":"invalid_credentials","message":"Incorrect email or password."}}
        """)
        XCTAssertEqual(error.error.code, "invalid_credentials")
        XCTAssertEqual(error.error.message, "Incorrect email or password.")
    }
}
