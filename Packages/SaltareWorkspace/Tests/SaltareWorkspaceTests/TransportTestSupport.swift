import XCTest
@testable import SaltareWorkspace

/// A scripted `URLProtocol` so the client's transport behaviour (status codes,
/// headers, retries) is testable without a server.
///
/// Responses are chosen by *content* — the request's path and bearer token —
/// rather than by arrival order, so tests that fire concurrent requests stay
/// deterministic.
final class StubTransport: URLProtocol, @unchecked Sendable {

    enum Response {
        case status(Int, Data)
        /// The connection never reached the server (airplane mode, dropped Wi-Fi).
        case transportFailure
    }

    struct Recorded {
        let path: String
        let authorization: String?
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> Response)?
    private nonisolated(unsafe) static var recorded: [Recorded] = []

    /// Install the responder and clear the log. Call from the test body.
    static func respond(_ handler: @escaping @Sendable (URLRequest) -> Response) {
        lock.lock(); defer { lock.unlock() }
        self.handler = handler
        recorded = []
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        handler = nil
        recorded = []
    }

    /// Every request the client actually sent, in order.
    static var requests: [Recorded] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    /// A session wired to this stub and nothing else.
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubTransport.self]
        return URLSession(configuration: configuration)
    }

    private static func resolve(_ request: URLRequest) -> Response {
        lock.lock(); defer { lock.unlock() }
        recorded.append(Recorded(path: request.url?.path ?? "",
                                 authorization: request.value(forHTTPHeaderField: "Authorization")))
        return handler?(request) ?? .status(500, Data())
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url else { return }
        switch Self.resolve(request) {
        case let .status(code, body):
            let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case .transportFailure:
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        }
    }
}

/// A `TokenVault` stand-in: hands out the access token, rotates on demand, and
/// records what the client asked it to do.
final class FakeVault: TokenProviding, TokenRefreshing, @unchecked Sendable {
    private let lock = NSLock()
    private var access: String?
    private var refresh: String?
    private var acceptCount = 0
    private var invalidateCount = 0
    private var refreshReadCount = 0

    init(access: String?, refresh: String?) {
        self.access = access
        self.refresh = refresh
    }

    var accepted: Int { lock.lock(); defer { lock.unlock() }; return acceptCount }
    var invalidated: Int { lock.lock(); defer { lock.unlock() }; return invalidateCount }
    var refreshReads: Int { lock.lock(); defer { lock.unlock() }; return refreshReadCount }
    var storedRefresh: String? { lock.lock(); defer { lock.unlock() }; return refresh }

    func accessToken() async -> String? {
        lock.lock(); defer { lock.unlock() }
        return access
    }

    func refreshToken() async -> String? {
        lock.lock(); defer { lock.unlock() }
        refreshReadCount += 1
        return refresh
    }

    func accept(_ tokens: AuthTokens) async {
        lock.lock(); defer { lock.unlock() }
        access = tokens.accessToken
        refresh = tokens.refreshToken
        acceptCount += 1
    }

    func invalidate() async {
        lock.lock(); defer { lock.unlock() }
        access = nil
        refresh = nil
        invalidateCount += 1
    }
}

/// `XCTAssertThrowsError` takes a non-async autoclosure, so async throwing calls
/// need their own spelling.
func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: String = "expected an error",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ onError: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail(message, file: file, line: line)
    } catch {
        onError(error)
    }
}
