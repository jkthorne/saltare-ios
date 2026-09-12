import Foundation

/// Supplies the current `sk_sal_` access token (resolved from the Keychain by
/// the app). Returns nil before sign-in.
public protocol TokenProviding: Sendable {
    func accessToken() async -> String?
}

public struct StaticToken: TokenProviding {
    private let token: String?
    public init(_ token: String?) { self.token = token }
    public func accessToken() async -> String? { token }
}

/// The rotating half of the session: supplies the `rt_sal_` refresh token and
/// takes custody of the rotated pair. Implemented by the app's Keychain vault.
///
/// Rotation lives here rather than in the UI layer because every caller of an
/// expired token hits the same 401 — the browser, the widget snapshot, the
/// agent's MCP connect — and none of them is in a position to notice.
public protocol TokenRefreshing: Sendable {
    func refreshToken() async -> String?
    /// Persist a freshly rotated session.
    func accept(_ tokens: AuthTokens) async
    /// The server rejected the refresh token: the session is unrecoverable and
    /// the stored credentials should be dropped.
    func invalidate() async
}

/// Serializes rotation so that a screen firing four parallel loads spends one
/// refresh token instead of four — the losers await the same in-flight attempt.
private actor RefreshGate {
    private var inFlight: Task<Bool, Never>?

    func run(_ rotate: @escaping @Sendable () async -> Bool) async -> Bool {
        if let inFlight { return await inFlight.value }
        let task = Task { await rotate() }
        inFlight = task
        defer { inFlight = nil }
        return await task.value
    }
}

/// Client for the saltare REST API. Bearer-token auth (`Authorization: Bearer
/// sk_sal_…`); resources unwrap `{data:…}`, auth/`me` decode directly. Foundation
/// only — `buildURLRequest` and the model decoders are unit-tested.
public final class WorkspaceClient: @unchecked Sendable {
    private let baseURL: URL
    private let tokens: TokenProviding
    private let refresher: TokenRefreshing?
    private let session: URLSession
    private let refreshes = RefreshGate()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    public init(baseURL: URL, tokens: TokenProviding, refresher: TokenRefreshing? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokens = tokens
        self.refresher = refresher
        self.session = session
    }

    // MARK: - Auth

    public func signIn(email: String, password: String, deviceId: String? = nil, deviceName: String? = nil, workspaceSlug: String? = nil) async throws -> AuthTokens {
        try await sendUnwrapped(WorkspaceEndpoint.token(email: email, password: password, deviceId: deviceId, deviceName: deviceName, workspaceSlug: workspaceSlug))
    }
    public func refresh(refreshToken: String) async throws -> AuthTokens {
        try await sendUnwrapped(WorkspaceEndpoint.refresh(refreshToken: refreshToken))
    }
    public func signOut() async throws { try await sendNoContent(WorkspaceEndpoint.signOut()) }
    public func me() async throws -> CurrentSession { try await sendUnwrapped(WorkspaceEndpoint.me()) }

    // MARK: - Resources (unwrap `{data:…}`)

    public func tasks(state: String? = nil, projectId: Int? = nil, page: Int? = nil) async throws -> [WorkspaceTask] {
        try await send(WorkspaceEndpoint.tasks(state: state, projectId: projectId, page: page))
    }
    public func task(slug: String) async throws -> WorkspaceTask { try await send(WorkspaceEndpoint.task(slug: slug)) }
    public func createTask(title: String, description: String? = nil, dueDate: String? = nil) async throws -> WorkspaceTask {
        try await send(WorkspaceEndpoint.createTask(title: title, description: description, dueDate: dueDate))
    }
    public func channels(page: Int? = nil) async throws -> [Channel] { try await send(WorkspaceEndpoint.channels(page: page)) }
    public func messages(channelId: Int, page: Int? = nil) async throws -> [Message] {
        try await send(WorkspaceEndpoint.messages(channelId: channelId, page: page))
    }
    public func sendMessage(channelId: Int, body: String) async throws -> Message {
        try await send(WorkspaceEndpoint.sendMessage(channelId: channelId, body: body))
    }
    public func agents(page: Int? = nil) async throws -> [Agent] { try await send(WorkspaceEndpoint.agents(page: page)) }
    public func agent(slug: String) async throws -> Agent { try await send(WorkspaceEndpoint.agent(slug: slug)) }
    public func messageAgent(slug: String, content: String) async throws -> Message {
        try await send(WorkspaceEndpoint.messageAgent(slug: slug, content: content))
    }
    public func documents(page: Int? = nil) async throws -> [Document] { try await send(WorkspaceEndpoint.documents(page: page)) }
    public func document(slug: String) async throws -> Document { try await send(WorkspaceEndpoint.document(slug: slug)) }

    // MARK: - Transport

    /// Resource send — unwraps the `{data:…}` envelope.
    func send<T: Decodable & Sendable>(_ request: WorkspaceRequest) async throws -> T {
        let envelope: DataEnvelope<T> = try await sendUnwrapped(request)
        return envelope.data
    }

    /// Raw send — decodes the body directly (auth + `me`).
    func sendUnwrapped<T: Decodable & Sendable>(_ request: WorkspaceRequest) async throws -> T {
        let data = try await perform(request)
        do { return try Self.decoder.decode(T.self, from: data) }
        catch { throw WorkspaceError.decoding(String(describing: error)) }
    }

    func sendNoContent(_ request: WorkspaceRequest) async throws { _ = try await perform(request) }

    private func perform(_ request: WorkspaceRequest) async throws -> Data {
        // An authed request may rotate once; the replay may not, so a genuinely
        // dead session surfaces its 401 instead of looping on the refresh.
        try await perform(request, mayRefresh: request.requiresAuth && refresher != nil)
    }

    private func perform(_ request: WorkspaceRequest, mayRefresh: Bool) async throws -> Data {
        var urlRequest = try buildURLRequest(request)
        if request.requiresAuth {
            guard let token = await tokens.accessToken(), !token.isEmpty else { throw WorkspaceError.notAuthenticated }
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: urlRequest) }
        catch { throw WorkspaceError.transport(error.localizedDescription) }

        guard let http = response as? HTTPURLResponse else { throw WorkspaceError.http(status: -1) }

        // The one failure worth retrying: the `sk_sal_` expired. Rotate with the
        // refresh token and replay the request with the new one.
        if http.statusCode == 401, mayRefresh, await rotate() {
            return try await perform(request, mayRefresh: false)
        }

        guard (200...299).contains(http.statusCode) else {
            if let body = try? Self.decoder.decode(ApiErrorBody.self, from: data) {
                throw WorkspaceError.api(code: body.error.code, message: body.error.message, status: http.statusCode)
            }
            throw WorkspaceError.http(status: http.statusCode)
        }
        return data
    }

    /// Exchange the refresh token for a new session. Returns false when there is
    /// nothing to rotate with, when the network is down, or when the server has
    /// retired the refresh token (in which case the stored session is dropped).
    private func rotate() async -> Bool {
        guard let refresher else { return false }
        return await refreshes.run { [self] in
            guard let refreshToken = await refresher.refreshToken(), !refreshToken.isEmpty else { return false }
            do {
                // `refresh` is an unauthenticated endpoint, so this nested call
                // can never re-enter rotation.
                let rotated: AuthTokens = try await sendUnwrapped(WorkspaceEndpoint.refresh(refreshToken: refreshToken))
                await refresher.accept(rotated)
                return true
            } catch {
                // Only a server rejection ends the session. A transport failure
                // is temporary, and throwing away a still-valid refresh token
                // over a dropped connection would sign the user out on a subway.
                if Self.isSessionEnding(error) { await refresher.invalidate() }
                return false
            }
        }
    }

    /// True when the server actively refused the refresh token, as opposed to
    /// never having been reached.
    static func isSessionEnding(_ error: Error) -> Bool {
        guard let error = error as? WorkspaceError else { return false }
        switch error {
        case let .api(_, _, status): return (400..<500).contains(status)
        case let .http(status): return (400..<500).contains(status)
        default: return false
        }
    }

    /// Builds the `URLRequest` (everything but the auth header, which needs the
    /// async token). Internal for tests.
    func buildURLRequest(_ request: WorkspaceRequest) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: false) else {
            throw WorkspaceError.http(status: -1)
        }
        if !request.query.isEmpty {
            components.queryItems = request.query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw WorkspaceError.http(status: -1) }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = request.body {
            urlRequest.httpBody = body
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return urlRequest
    }
}
