import XCTest
@testable import SaltareWorkspace

/// The 401 → rotate → replay path in `WorkspaceClient`.
///
/// Every one of these runs against a scripted transport that answers by
/// *content* (path + the bearer token the request carried) rather than by
/// arrival order, so the concurrency case below is deterministic.
final class TokenRefreshTests: XCTestCase {

    private let baseURL = URL(string: "https://saltare.ai")!

    override func tearDown() {
        StubTransport.reset()
        super.tearDown()
    }

    // MARK: - Fixtures

    /// The server's own `device_session` golden with the tokens swapped, so the
    /// rotated session is pinned to the shape the server actually emits.
    private func rotatedSession(access: String, refresh: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "device_session", withExtension: "json", subdirectory: "api_golden"))
        var payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        payload["access_token"] = access
        payload["refresh_token"] = refresh
        return try JSONSerialization.data(withJSONObject: payload)
    }

    /// Answers `/auth/refresh` with a rotated session and `/tasks` with an empty
    /// collection — but only for a request carrying `accepting`; anything else
    /// gets the 401 an expired `sk_sal_` earns.
    private func serverExpiring(accepting fresh: String) throws -> @Sendable (URLRequest) -> StubTransport.Response {
        let rotated = try rotatedSession(access: fresh, refresh: "rt_sal_rotated")
        return { request in
            if request.url?.path.hasSuffix("/auth/refresh") == true { return .status(200, rotated) }
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer \(fresh)" {
                return .status(200, Data(#"{"data":[]}"#.utf8))
            }
            return .status(401, Data(#"{"error":{"code":"unauthorized","message":"token expired"}}"#.utf8))
        }
    }

    // MARK: - Rotation

    func testExpiredAccessTokenRotatesAndReplaysTheRequest() async throws {
        let vault = FakeVault(access: "sk_sal_stale", refresh: "rt_sal_good")
        StubTransport.respond(try serverExpiring(accepting: "sk_sal_fresh"))
        let client = WorkspaceClient(baseURL: baseURL, tokens: vault, refresher: vault, session: StubTransport.session())

        let tasks = try await client.tasks()

        XCTAssertEqual(tasks.count, 0, "the replay succeeded and decoded")
        XCTAssertEqual(vault.accepted, 1, "the rotated session was persisted exactly once")
        XCTAssertEqual(vault.invalidated, 0)

        let paths = StubTransport.requests.map(\.path)
        XCTAssertEqual(paths, ["/api/v1/tasks", "/api/v1/auth/refresh", "/api/v1/tasks"],
                       "the 401 is followed by a refresh, then the same request again")
        XCTAssertEqual(StubTransport.requests.first?.authorization, "Bearer sk_sal_stale")
        XCTAssertEqual(StubTransport.requests.last?.authorization, "Bearer sk_sal_fresh",
                       "the replay carries the rotated token, not the expired one")
    }

    func testRotationHappensOnceForConcurrentRequests() async throws {
        let vault = FakeVault(access: "sk_sal_stale", refresh: "rt_sal_good")
        StubTransport.respond(try serverExpiring(accepting: "sk_sal_fresh"))
        let client = WorkspaceClient(baseURL: baseURL, tokens: vault, refresher: vault, session: StubTransport.session())

        // The workspace browser opens four tabs at once; one expired token.
        async let channels = client.channels()
        async let tasks = client.tasks()
        async let agents = client.agents()
        async let documents = client.documents()
        _ = try await (channels, tasks, agents, documents)

        XCTAssertEqual(vault.refreshReads, 1, "parallel 401s join one rotation instead of spending four refresh tokens")
        XCTAssertEqual(vault.accepted, 1)
        XCTAssertEqual(StubTransport.requests.filter { $0.path.hasSuffix("/auth/refresh") }.count, 1)
    }

    func testReplayIsNotRetriedAgain() async throws {
        let vault = FakeVault(access: "sk_sal_stale", refresh: "rt_sal_good")
        let rotated = try rotatedSession(access: "sk_sal_fresh", refresh: "rt_sal_rotated")
        // A server that 401s no matter which token it is handed.
        StubTransport.respond { request in
            request.url?.path.hasSuffix("/auth/refresh") == true ? .status(200, rotated) : .status(401, Data())
        }
        let client = WorkspaceClient(baseURL: baseURL, tokens: vault, refresher: vault, session: StubTransport.session())

        await XCTAssertThrowsErrorAsync(try await client.tasks()) { error in
            XCTAssertEqual(error as? WorkspaceError, WorkspaceError.http(status: 401),
                           "the second 401 surfaces rather than looping")
        }
        XCTAssertEqual(StubTransport.requests.filter { $0.path.hasSuffix("/auth/refresh") }.count, 1,
                       "one rotation per request, never a refresh loop")
    }

    // MARK: - When rotation fails

    func testRejectedRefreshTokenEndsTheSession() async throws {
        let vault = FakeVault(access: "sk_sal_stale", refresh: "rt_sal_revoked")
        StubTransport.respond { _ in
            .status(401, Data(#"{"error":{"code":"invalid_token","message":"refresh token revoked"}}"#.utf8))
        }
        let client = WorkspaceClient(baseURL: baseURL, tokens: vault, refresher: vault, session: StubTransport.session())

        await XCTAssertThrowsErrorAsync(try await client.tasks())

        XCTAssertEqual(vault.invalidated, 1, "a refused refresh token means the stored session is dead")
        XCTAssertEqual(vault.accepted, 0)
    }

    func testTransportFailureKeepsTheRefreshTokenForLater() async throws {
        let vault = FakeVault(access: "sk_sal_stale", refresh: "rt_sal_good")
        StubTransport.respond { request in
            request.url?.path.hasSuffix("/auth/refresh") == true ? .transportFailure : .status(401, Data())
        }
        let client = WorkspaceClient(baseURL: baseURL, tokens: vault, refresher: vault, session: StubTransport.session())

        await XCTAssertThrowsErrorAsync(try await client.tasks())

        XCTAssertEqual(vault.invalidated, 0,
                       "a dropped connection must not sign the user out — the refresh token is still good")
        XCTAssertEqual(vault.storedRefresh, "rt_sal_good")
    }

    func testWithoutARefresherA401IsJustAn401() async throws {
        let vault = FakeVault(access: "sk_sal_stale", refresh: "rt_sal_good")
        StubTransport.respond { _ in .status(401, Data()) }
        let client = WorkspaceClient(baseURL: baseURL, tokens: vault, session: StubTransport.session())

        await XCTAssertThrowsErrorAsync(try await client.tasks())

        XCTAssertEqual(StubTransport.requests.count, 1, "no refresher wired means no rotation attempt")
        XCTAssertEqual(vault.refreshReads, 0)
    }

    // MARK: - Error classification

    func testOnlyServerRejectionsEndTheSession() {
        XCTAssertTrue(WorkspaceClient.isSessionEnding(WorkspaceError.http(status: 401)))
        XCTAssertTrue(WorkspaceClient.isSessionEnding(WorkspaceError.api(code: "invalid_token", message: "no", status: 403)))
        XCTAssertFalse(WorkspaceClient.isSessionEnding(WorkspaceError.http(status: 500)),
                       "a server fault is not the user's session being over")
        XCTAssertFalse(WorkspaceClient.isSessionEnding(WorkspaceError.transport("offline")))
        XCTAssertFalse(WorkspaceClient.isSessionEnding(WorkspaceError.decoding("garbage")))
    }
}
