import Foundation

/// A websocket client for saltare's Action Cable endpoint (`<base>/cable`).
/// Opens one `URLSessionWebSocketTask`, attaches the workspace bearer token as an
/// `Authorization` header on the handshake, and streams decoded `CableEvent`s.
/// The protocol framing lives in `ActionCableProtocol`
/// (pure + tested); this is the thin transport around it.
///
/// Subscriptions are multiplexed on the one socket — `subscribe`/`unsubscribe`/
/// `perform` send commands; the consumer filters the event stream by identifier.
///
/// Foundation-only. Reconnect/backoff is intentionally out of scope for this
/// milestone (the stream finishes on socket close; the caller re-`connect`s).
public final class RealtimeClient: NSObject, @unchecked Sendable {
    private let cableURL: URL
    private let tokens: TokenProviding
    private let session: URLSession

    private let lock = NSLock()
    private var task: URLSessionWebSocketTask?
    private var continuation: AsyncStream<CableEvent>.Continuation?

    public init(baseURL: URL, tokens: TokenProviding, session: URLSession = .shared) {
        self.cableURL = Self.cableURL(from: baseURL)
        self.tokens = tokens
        self.session = session
    }

    /// Open the socket and return a stream of every cable event. Terminating the
    /// stream (or calling `disconnect()`) closes the socket. Re-`connect()` after
    /// a close to reconnect.
    public func connect() async -> AsyncStream<CableEvent> {
        let token = await tokens.accessToken()
        let socket = session.webSocketTask(with: Self.handshakeRequest(url: cableURL, token: token))

        return AsyncStream<CableEvent> { continuation in
            lock.lock()
            task?.cancel(with: .goingAway, reason: nil) // replace any prior socket
            task = socket
            self.continuation = continuation
            lock.unlock()

            continuation.onTermination = { [weak self] _ in self?.disconnect() }
            socket.resume()
            receive(on: socket, continuation)
        }
    }

    public func subscribe(_ identifier: CableIdentifier) async {
        await send(.subscribe(identifier))
    }

    public func unsubscribe(_ identifier: CableIdentifier) async {
        await send(.unsubscribe(identifier))
    }

    public func perform(_ identifier: CableIdentifier, action: String, payload: [String: CableValue] = [:]) async {
        await send(.message(identifier, action: action, payload: payload))
    }

    public func disconnect() {
        lock.lock()
        let socket = task
        let continuation = self.continuation
        task = nil
        self.continuation = nil
        lock.unlock()
        socket?.cancel(with: .goingAway, reason: nil)
        continuation?.finish()
    }

    // MARK: - Transport

    private func send(_ command: CableCommand) async {
        guard let socket = currentSocket() else { return }
        let text = String(decoding: ActionCableProtocol.encode(command), as: UTF8.self)
        try? await socket.send(.string(text))
    }

    /// Sync locked read — `NSLock.unlock()` is unavailable from async contexts.
    private func currentSocket() -> URLSessionWebSocketTask? {
        lock.lock(); defer { lock.unlock() }
        return task
    }

    /// Recursive receive loop — decodes each frame and yields it, finishing the
    /// stream when the socket errors or closes.
    private func receive(on socket: URLSessionWebSocketTask, _ continuation: AsyncStream<CableEvent>.Continuation) {
        socket.receive { [weak self] result in
            switch result {
            case let .success(message):
                let data: Data
                switch message {
                case let .string(string): data = Data(string.utf8)
                case let .data(bytes): data = bytes
                @unknown default: data = Data()
                }
                if !data.isEmpty { continuation.yield(ActionCableProtocol.decode(data)) }
                self?.receive(on: socket, continuation)
            case .failure:
                continuation.finish()
            }
        }
    }

    // MARK: - URL

    /// The handshake request. The token rides the `Authorization` header and
    /// nothing else: a URL query parameter would be written verbatim into every
    /// proxy and server access log it passes through, and `sk_sal_` is a bearer
    /// credential — whoever reads the log has the session.
    ///
    /// The server accepts either (`ApplicationCable::Connection#user_from_token`);
    /// the query param exists for browser clients, which cannot set handshake
    /// headers. `URLSessionWebSocketTask` can, so it should.
    ///
    /// Internal for tests.
    static func handshakeRequest(url: URL, token: String?) -> URLRequest {
        var request = URLRequest(url: url)
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// `https://host` → `wss://host/cable`, `http://host` → `ws://host/cable`.
    static func cableURL(from base: URL) -> URL {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return base }
        components.scheme = (components.scheme == "http") ? "ws" : "wss"
        components.path = "/cable"
        components.query = nil
        return components.url ?? base
    }
}
