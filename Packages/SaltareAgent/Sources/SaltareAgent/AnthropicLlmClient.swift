import Foundation

/// Configuration for the Anthropic client. The API key is fetched per request
/// through a closure so the app can resolve it from the Keychain (and gate on
/// biometrics) without this layer depending on Security/UIKit.
public struct AnthropicConfig: Sendable {
    public var baseURL: URL
    public var anthropicVersion: String
    public var maxTokens: Int
    public var systemStable: String
    /// Renders the volatile system suffix (time/locale/model) for a request.
    public var volatile: @Sendable (AgentModel) -> String
    /// Resolves the API key (e.g. from the Keychain); `nil` → falls back to a
    /// "no key" failure so the UI can prompt.
    public var apiKey: @Sendable () async -> String?

    public init(
        baseURL: URL = URL(string: "https://api.anthropic.com")!,
        anthropicVersion: String = "2023-06-01",
        maxTokens: Int = AnthropicRequest.defaultMaxTokens,
        systemStable: String = SystemPromptText.stable,
        volatile: @escaping @Sendable (AgentModel) -> String,
        apiKey: @escaping @Sendable () async -> String?
    ) {
        self.baseURL = baseURL
        self.anthropicVersion = anthropicVersion
        self.maxTokens = maxTokens
        self.systemStable = systemStable
        self.volatile = volatile
        self.apiKey = apiKey
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
        guard let key = await config.apiKey(), !key.isEmpty else {
            continuation.yield(.failed(message: "No Anthropic API key set.", retryable: false))
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

        var urlRequest = URLRequest(url: config.baseURL.appendingPathComponent("v1/messages"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(key, forHTTPHeaderField: "x-api-key")
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
