import Foundation
@testable import SaltareAgent

/// Scripted fake: one inner list of events per expected request.
final class FakeLlmClient: LlmClient, @unchecked Sendable {
    private let lock = NSLock()
    private let script: [[LlmStreamEvent]]
    private var _requests: [LlmRequest] = []

    init(_ script: [[LlmStreamEvent]]) { self.script = script }

    var requestCount: Int { lock.lock(); defer { lock.unlock() }; return _requests.count }

    func streamTurn(_ request: LlmRequest) -> AsyncStream<LlmStreamEvent> {
        lock.lock()
        _requests.append(request)
        let index = _requests.count - 1
        lock.unlock()
        let events = script[index] // crash on unscripted request, like the Kotlin error()
        return AsyncStream { continuation in
            for event in events { continuation.yield(event) }
            continuation.finish()
        }
    }
}

/// Yields one text delta, then hangs until cancelled — for the
/// cancel-mid-stream invariant.
struct HangingLlmClient: LlmClient {
    func streamTurn(_ request: LlmRequest) -> AsyncStream<LlmStreamEvent> {
        AsyncStream { continuation in
            let task = Task {
                continuation.yield(.textDelta("partial answer"))
                while !Task.isCancelled { try? await Task.sleep(for: .milliseconds(20)) }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Executor double that bypasses the tool registry.
actor ScriptedExecutor: ToolRunner {
    private var outcomes: [String: [ToolOutcome]]
    private(set) var executed: [String] = []

    init(_ outcomes: [String: [ToolOutcome]] = [:]) { self.outcomes = outcomes }

    func execute(_ name: String, _ input: [String: JSONValue]) async -> ToolOutcome {
        executed.append(name)
        if var list = outcomes[name], !list.isEmpty {
            let next = list.removeFirst()
            outcomes[name] = list
            return next
        }
        return .error("unscripted tool \(name)")
    }
}

// MARK: - turn builders (mirror the Kotlin helpers)

func textTurn(_ text: String) -> [LlmStreamEvent] {
    [.textDelta(text), .completed(stopReason: .endTurn, assistantBlocks: [.text(text)])]
}

func toolTurn(_ uses: AssistantBlock...) -> [LlmStreamEvent] {
    [.completed(stopReason: .toolUse, assistantBlocks: uses)]
}
