import XCTest
@testable import SaltareWorkspace

final class EndpointTests: XCTestCase {

    private func bodyObject(_ request: WorkspaceRequest) throws -> [String: Any] {
        let data = try XCTUnwrap(request.body)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testReadEndpoints() {
        XCTAssertEqual(WorkspaceEndpoint.me(), WorkspaceRequest(method: "GET", path: "api/v1/me"))
        XCTAssertEqual(WorkspaceEndpoint.task(slug: "ship"), WorkspaceRequest(method: "GET", path: "api/v1/tasks/ship"))
        XCTAssertEqual(WorkspaceEndpoint.tasks(state: "open", page: 2),
                       WorkspaceRequest(method: "GET", path: "api/v1/tasks", query: ["state": "open", "page": "2"]))
        XCTAssertEqual(WorkspaceEndpoint.messages(channelId: 4),
                       WorkspaceRequest(method: "GET", path: "api/v1/messages", query: ["channel_id": "4"]))
    }

    func testAuthEndpointsSkipBearer() {
        XCTAssertFalse(WorkspaceEndpoint.token(email: "a@b.co", password: "pw").requiresAuth)
        XCTAssertFalse(WorkspaceEndpoint.refresh(refreshToken: "rt").requiresAuth)
        XCTAssertTrue(WorkspaceEndpoint.signOut().requiresAuth)
    }

    func testTokenBodyUsesEmailAddressAndOmitsNils() throws {
        let body = try bodyObject(WorkspaceEndpoint.token(email: "a@b.co", password: "pw", deviceName: "iPhone"))
        XCTAssertEqual(body["email_address"] as? String, "a@b.co")
        XCTAssertEqual(body["password"] as? String, "pw")
        XCTAssertEqual(body["platform"] as? String, "ios")
        XCTAssertEqual(body["device_name"] as? String, "iPhone")
        XCTAssertNil(body["device_id"]) // nil optionals omitted
        XCTAssertNil(body["workspace_slug"])
    }

    func testCreateTaskNestsUnderTaskKey() throws {
        let body = try bodyObject(WorkspaceEndpoint.createTask(title: "Hi"))
        let task = try XCTUnwrap(body["task"] as? [String: Any])
        XCTAssertEqual(task["title"] as? String, "Hi")
        XCTAssertNil(task["description"])
    }

    func testSendMessageNestsUnderMessageKey() throws {
        let request = WorkspaceEndpoint.sendMessage(channelId: 7, body: "hey")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "api/v1/messages")
        let message = try XCTUnwrap(try bodyObject(request)["message"] as? [String: Any])
        XCTAssertEqual(message["channel_id"] as? Int, 7)
        XCTAssertEqual(message["body"] as? String, "hey")
    }

    func testMessageAgentUsesContent() throws {
        let request = WorkspaceEndpoint.messageAgent(slug: "researcher", content: "summarize")
        XCTAssertEqual(request.path, "api/v1/agents/researcher/message")
        XCTAssertEqual(try bodyObject(request)["content"] as? String, "summarize")
    }

    func testBuildURLRequestSortsQueryAndSetsHeaders() throws {
        let client = WorkspaceClient(baseURL: URL(string: "https://saltare.ai")!, tokens: StaticToken(nil))
        let urlRequest = try client.buildURLRequest(WorkspaceEndpoint.tasks(state: "open", page: 2))
        XCTAssertEqual(urlRequest.url?.absoluteString, "https://saltare.ai/api/v1/tasks?page=2&state=open")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Accept"), "application/json")

        let post = try client.buildURLRequest(WorkspaceEndpoint.createTask(title: "Hi"))
        XCTAssertEqual(post.httpMethod, "POST")
        XCTAssertEqual(post.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(post.httpBody)
    }
}
