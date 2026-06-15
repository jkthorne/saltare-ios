import Foundation

/// How the request authenticates — direct Anthropic (`x-api-key`) or the
/// saltare inference proxy (`Authorization: Bearer` with the workspace token).
public enum AnthropicCredential: Sendable {
    case apiKey(String)
    case bearer(String)
}

/// Where a request goes + how it authenticates. Resolved per request so the
/// agent can switch between the saltare inference proxy (when signed in) and
/// direct Anthropic (a pasted key) without rebuilding.
public struct AnthropicEndpoint: Sendable {
    public let baseURL: URL
    public let credential: AnthropicCredential
    public init(baseURL: URL, credential: AnthropicCredential) {
        self.baseURL = baseURL
        self.credential = credential
    }
}

/// Configuration for the Anthropic client. The endpoint (base URL + credential)
/// is resolved per request through a closure so the app can pick the inference
/// proxy or a pasted key without this layer touching Security/UIKit.
public struct AnthropicConfig: Sendable {
    public var anthropicVersion: String
    public var maxTokens: Int
    public var systemStable: String
    /// Renders the volatile system suffix (time/locale/model) for a request.
    public var volatile: @Sendable (AgentModel) -> String
    /// Resolves the endpoint; `nil` → a "no credentials" failure the UI prompts on.
    public var endpoint: @Sendable () async -> AnthropicEndpoint?

    public init(
        anthropicVersion: String = "2023-06-01",
        maxTokens: Int = AnthropicRequest.defaultMaxTokens,
        systemStable: String = SystemPromptText.stable,
        volatile: @escaping @Sendable (AgentModel) -> String,
        endpoint: @escaping @Sendable () async -> AnthropicEndpoint?
    ) {
        self.anthropicVersion = anthropicVersion
        self.maxTokens = maxTokens
        self.systemStable = systemStable
        self.volatile = volatile
        self.endpoint = endpoint
    }
}

/// `LlmClient` over the Anthropic Messages API, streaming SSE via
/// `URLSession.bytes`. Foundation-only (no SDK) — the manual tool loop's network
/// boundary.
public final class AnthropicLlmClient: LlmClient, @unchecked Sendable {
    private let config: AnthropicConfig
    private let session: URLSession

    public init(config: AnthropicConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    public func streamTurn(_ request: LlmRequest) -> AsyncStream<LlmStreamEvent> {
        AsyncStream { continuation in
            let task = Task {
                await self.stream(request, into: continuation)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func stream(_ request: LlmRequest, into continuation: AsyncStream<LlmStreamEvent>.Continuation) async {
        guard let endpoint = await config.endpoint() else {
            continuation.yield(.failed(message: "No agent credentials. Sign in to saltare or add an Anthropic API key.", retryable: false))
            return
        }

        let body = AnthropicRequest.body(
            model: request.model,
            history: request.history,
            tools: request.tools,
            systemStable: config.systemStable,
            systemVolatile: config.volatile(request.model),
            maxTokens: config.maxTokens
        )

        var urlRequest = URLRequest(url: endpoint.baseURL.appendingPathComponent("v1/messages"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        switch endpoint.credential {
        case let .apiKey(key): urlRequest.setValue(key, forHTTPHeaderField: "x-api-key")
        case let .bearer(token): urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.setValue(config.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        do {
            urlRequest.httpBody = try body.serializedData()
        } catch {
            continuation.yield(.failed(message: "Failed to encode request.", retryable: false))
            return
        }

        let parser = AnthropicSSEParser()
        do {
            let (bytes, response) = try await session.bytes(for: urlRequest)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let retryable = http.statusCode == 429 || http.statusCode >= 500
                continuation.yield(.failed(message: "Anthropic API error (HTTP \(http.statusCode)).", retryable: retryable))
                return
            }
            for try await line in bytes.lines {
                if Task.isCancelled { return }
                guard line.hasPrefix("data:") else { continue } // skip "event:" / blank lines
                let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                if payload.isEmpty || payload == "[DONE]" { continue }
                if let value = JSONValue.parse(payload) {
                    for event in parser.handle(value) {
                        continuation.yield(event)
                    }
                }
            }
        } catch {
            if Task.isCancelled { return }
            continuation.yield(.failed(message: error.localizedDescription, retryable: true))
        }
    }
}
