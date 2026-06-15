import Foundation

/// Where the MCP endpoint lives + how to authenticate it. The token is resolved
/// per request (a closure) so a sign-in mid-session makes the agent's workspace
/// tools live without rebuilding the client.
public struct McpConfig: Sendable {
    public var endpoint: URL
    public var bearerToken: @Sendable () async -> String?
    public var protocolVersion: String
    public var clientName: String
    public var clientVersion: String

    public init(
        endpoint: URL,
        bearerToken: @escaping @Sendable () async -> String?,
        protocolVersion: String = "2025-03-26",
        clientName: String = "saltare-ios",
        clientVersion: String = "0.1"
    ) {
        self.endpoint = endpoint
        self.bearerToken = bearerToken
        self.protocolVersion = protocolVersion
        self.clientName = clientName
        self.clientVersion = clientVersion
    }
}

public enum McpError: Error, Sendable, Equatable {
    case noToken
    case http(Int)
    case rpc(code: Int, message: String)
    case transport(String)
    case decoding
}

/// Minimal MCP client over saltare's Streamable-HTTP `/mcp` endpoint. Uses the
/// JSON-RPC-over-POST path with `Accept: application/json` (plain JSON, not SSE)
/// — every request/response (`initialize`, `tools/list`, `tools/call`) returns a
/// single JSON body, so no event-stream parsing is needed. The session id the
/// server hands back on `initialize` is echoed on subsequent requests.
///
/// Foundation-only (`URLSession`) — the agent's seam onto the workspace. The
/// `ToolSpec`s it produces append AFTER the local tools (`saltare__` prefix),
/// preserving the prompt-cache prefix.
public final class McpClient: @unchecked Sendable {
    private let config: McpConfig
    private let session: URLSession

    private let lock = NSLock()
    private var sessionId: String?
    private var nextId = 1

    public init(config: McpConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// Connect, enumerate, and return the workspace tools as prefixed
    /// `ToolSpec`s ready for `ToolRegistry.remoteTools`.
    public func loadTools(prefix: String = McpToolSource.defaultPrefix) async throws -> [ToolSpec] {
        try await connect()
        let listResult = try await rpc(method: "tools/list", params: .object([:]))
        return McpToolSource.toolSpecs(listResult: listResult, prefix: prefix) { [weak self] name, arguments in
            await self?.callTool(name, arguments: arguments) ?? .error("MCP client released.")
        }
    }

    /// `initialize` + the `notifications/initialized` ack per the MCP lifecycle.
    public func connect() async throws {
        let params: JSONValue = .object([
            "protocolVersion": .string(config.protocolVersion),
            "capabilities": .object([:]),
            "clientInfo": .object([
                "name": .string(config.clientName),
                "version": .string(config.clientVersion),
            ]),
        ])
        _ = try await rpc(method: "initialize", params: params)
        try? await notify(method: "notifications/initialized")
    }

    /// Invoke one workspace tool, mapping the MCP result/`isError` envelope onto
    /// a `ToolOutcome`. Never throws — RPC failures become `.error` so one bad
    /// tool call can't tear down the agent turn.
    public func callTool(_ name: String, arguments: [String: JSONValue]) async -> ToolOutcome {
        let params: JSONValue = .object([
            "name": .string(name),
            "arguments": .object(arguments),
        ])
        do {
            let result = try await rpc(method: "tools/call", params: params)
            return McpToolSource.outcome(fromCallResult: result)
        } catch let McpError.rpc(_, message) {
            return .error(message)
        } catch McpError.noToken {
            return .error("Not signed in to saltare.")
        } catch {
            return .error("Workspace tool call failed.")
        }
    }

    // MARK: - JSON-RPC transport

    private func rpc(method: String, params: JSONValue) async throws -> JSONValue {
        let body: JSONValue = .object([
            "jsonrpc": .string("2.0"),
            "id": .number(Double(nextRequestId())),
            "method": .string(method),
            "params": params,
        ])
        let data = try await post(body)
        guard let json = JSONValue.parse(data) else { throw McpError.decoding }
        if let error = json["error"],
           let code = error["code"]?.intValue,
           let message = error["message"]?.stringValue {
            throw McpError.rpc(code: code, message: message)
        }
        guard let result = json["result"] else { throw McpError.decoding }
        return result
    }

    /// A notification has no `id` and expects no response (the server replies 202).
    private func notify(method: String) async throws {
        let body: JSONValue = .object([
            "jsonrpc": .string("2.0"),
            "method": .string(method),
            "params": .object([:]),
        ])
        _ = try await post(body)
    }

    private func post(_ body: JSONValue) async throws -> Data {
        guard let token = await config.bearerToken(), !token.isEmpty else { throw McpError.noToken }

        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept") // plain JSON, not text/event-stream
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let id = currentSessionId() {
            request.setValue(id, forHTTPHeaderField: "Mcp-Session-Id")
        }
        request.httpBody = try body.serializedData()

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw McpError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw McpError.http(-1) }
        if let id = http.value(forHTTPHeaderField: "Mcp-Session-Id") {
            setSessionId(id)
        }
        guard (200...299).contains(http.statusCode) else { throw McpError.http(http.statusCode) }
        return data
    }

    // MARK: - Locked state

    private func nextRequestId() -> Int {
        lock.lock(); defer { lock.unlock() }
        let id = nextId
        nextId += 1
        return id
    }

    private func currentSessionId() -> String? {
        lock.lock(); defer { lock.unlock() }
        return sessionId
    }

    private func setSessionId(_ id: String) {
        lock.lock(); defer { lock.unlock() }
        sessionId = id
    }
}
