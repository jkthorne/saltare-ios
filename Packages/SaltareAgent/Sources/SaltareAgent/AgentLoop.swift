import Foundation

/// The manual tool loop for one user turn. Invariants (ported from the Android
/// `:agent` `AgentLoop`):
///  - every `tool_use` id gets exactly one `tool_result`, all results for a
///    response collected into ONE `toolResults` message before the next request;
///  - a `needsPermission` outcome HOLDS the loop until the UI resolves
///    `awaitPermission`, then re-executes;
///  - assistant blocks (including thinking signatures) are echoed verbatim;
///  - a failed/cancelled first request leaves history untouched.
public final class AgentLoop: Sendable {
    private let llm: LlmClient
    private let executor: ToolRunner
    private let maxIterations: Int

    public init(llm: LlmClient, executor: ToolRunner, maxIterations: Int = 5) {
        self.llm = llm
        self.executor = executor
        self.maxIterations = maxIterations
    }

    /// Drives one turn, delivering events through `onEvent`. The caller owns the
    /// task — cancelling it mid-stream stops cleanly with no half-echo. Use
    /// `runStream` for an `AsyncStream` instead.
    public func run(
        history: AgentHistory,
        userText: String,
        tools: [ToolSpec],
        model: AgentModel,
        awaitPermission: @escaping @Sendable (String) async -> Bool,
        onEvent: @escaping @Sendable (AgentEvent) -> Void
    ) async {
        history.append(.user(userText))
        var firstRequest = true

        for _ in 0..<maxIterations {
            var completed: (stopReason: StopReason, blocks: [AssistantBlock])?
            var failed: (message: String, retryable: Bool)?

            for await event in llm.streamTurn(LlmRequest(model: model, history: history.messages, tools: tools)) {
                switch event {
                case let .textDelta(text): onEvent(.textDelta(text))
                case let .completed(reason, blocks): completed = (reason, blocks)
                case let .failed(message, retryable): failed = (message, retryable)
                }
            }

            // Cancelled mid-stream: leave the (incomplete) turn unechoed.
            if Task.isCancelled { return }

            if let failed {
                if firstRequest { history.removeLast() } // a retry re-adds the user turn
                onEvent(.error(message: failed.message, retryable: failed.retryable))
                return
            }
            guard let turn = completed else {
                if firstRequest { history.removeLast() }
                onEvent(.error(message: "Empty response from model", retryable: true))
                return
            }
            firstRequest = false

            history.append(.assistant(turn.blocks))

            let toolUses: [(id: String, name: String, input: [String: JSONValue])] = turn.blocks.compactMap {
                if case let .toolUse(id, name, input) = $0 { return (id, name, input) }
                return nil
            }
            if turn.stopReason != .toolUse || toolUses.isEmpty {
                onEvent(.turnComplete)
                return
            }

            var results: [ToolResult] = []
            for use in toolUses {
                onEvent(.toolCallStarted(id: use.id, name: use.name, input: use.input))
                var outcome = await executor.execute(use.name, use.input)
                if case let .needsPermission(permission) = outcome {
                    onEvent(.toolResultReady(id: use.id, name: use.name, outcome: outcome))
                    if await awaitPermission(permission) {
                        outcome = await executor.execute(use.name, use.input)
                    } else {
                        outcome = .error("User declined the permission — do not retry this tool.")
                    }
                }
                onEvent(.toolResultReady(id: use.id, name: use.name, outcome: outcome))

                let text: String
                let isError: Bool
                switch outcome {
                case let .success(value): text = value; isError = false
                case let .error(value): text = value; isError = true
                case .needsPermission: text = "Permission not granted."; isError = true
                }
                results.append(ToolResult(toolUseId: use.id, text: text, isError: isError))
            }
            history.append(.toolResults(results))
        }

        onEvent(.error(message: "Tool loop limit reached.", retryable: false))
    }

    /// An `AsyncStream` wrapper over `run` — ergonomic for the UI
    /// (`for await event in loop.runStream(...)`). Terminating the stream
    /// cancels the underlying turn.
    public func runStream(
        history: AgentHistory,
        userText: String,
        tools: [ToolSpec],
        model: AgentModel,
        awaitPermission: @escaping @Sendable (String) async -> Bool
    ) -> AsyncStream<AgentEvent> {
        AsyncStream { continuation in
            let task = Task {
                await run(
                    history: history,
                    userText: userText,
                    tools: tools,
                    model: model,
                    awaitPermission: awaitPermission,
                    onEvent: { continuation.yield($0) }
                )
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
