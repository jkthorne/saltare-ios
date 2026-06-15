import XCTest
@testable import SaltareAgent

/// Ported from the Android `:agent` `AgentLoopTest`.
final class AgentLoopTests: XCTestCase {

    private func collect(
        _ loop: AgentLoop,
        history: AgentHistory,
        userText: String,
        tools: [ToolSpec] = [],
        model: AgentModel = .opus,
        awaitPermission: @escaping @Sendable (String) async -> Bool = { _ in true }
    ) async -> [AgentEvent] {
        var events: [AgentEvent] = []
        for await event in loop.runStream(
            history: history, userText: userText, tools: tools, model: model, awaitPermission: awaitPermission
        ) {
            events.append(event)
        }
        return events
    }

    func testPlainTextTurn() async {
        let history = AgentHistory()
        let llm = FakeLlmClient([textTurn("Hello.")])
        let loop = AgentLoop(llm: llm, executor: ScriptedExecutor())

        let events = await collect(loop, history: history, userText: "hi")

        XCTAssertEqual(events, [.textDelta("Hello."), .turnComplete])
        XCTAssertEqual(history.messages.count, 2) // user + assistant echo
        XCTAssertEqual(llm.requestCount, 1)
    }

    func testSingleToolRound() async {
        let history = AgentHistory()
        let executor = ScriptedExecutor(["phone_call": [.success("Opened dialer")]])
        let llm = FakeLlmClient([
            toolTurn(.toolUse(id: "t1", name: "phone_call", input: ["number": .string("1")])),
            textTurn("Done."),
        ])
        let loop = AgentLoop(llm: llm, executor: executor)

        let events = await collect(loop, history: history, userText: "call 1")

        XCTAssertTrue(events.contains { if case .toolCallStarted(_, "phone_call", _) = $0 { return true }; return false })
        XCTAssertTrue(events.contains { if case .toolResultReady(_, _, .success("Opened dialer")) = $0 { return true }; return false })
        XCTAssertEqual(events.last, .turnComplete)
        // history: user, assistant(tool_use), tool_results, assistant(text)
        XCTAssertEqual(history.messages.count, 4)
        guard case let .toolResults(results) = history.messages[2] else { return XCTFail() }
        XCTAssertEqual(results.first?.toolUseId, "t1")
        XCTAssertEqual(llm.requestCount, 2)
    }

    func testParallelToolUsesAllResolveIntoOneMessage() async {
        let history = AgentHistory()
        let executor = ScriptedExecutor(["a": [.success("ra")], "b": [.error("rb")]])
        let llm = FakeLlmClient([
            toolTurn(
                .toolUse(id: "t1", name: "a", input: [:]),
                .toolUse(id: "t2", name: "b", input: [:])
            ),
            textTurn("Both handled."),
        ])
        let loop = AgentLoop(llm: llm, executor: executor)

        _ = await collect(loop, history: history, userText: "do both")

        guard case let .toolResults(results) = history.messages[2] else { return XCTFail() }
        XCTAssertEqual(results.map(\.toolUseId), ["t1", "t2"])
        XCTAssertEqual(results.map(\.isError), [false, true])
        XCTAssertEqual(llm.requestCount, 2) // both results travelled in ONE follow-up
    }

    func testIterationCapEmitsError() async {
        let endless = toolTurn(.toolUse(id: "t", name: "a", input: [:]))
        let executor = ScriptedExecutor(["a": Array(repeating: .success("ok"), count: 5)])
        let loop = AgentLoop(llm: FakeLlmClient(Array(repeating: endless, count: 5)), executor: executor, maxIterations: 5)

        let events = await collect(loop, history: AgentHistory(), userText: "go")

        guard case let .error(message, retryable) = events.last else { return XCTFail() }
        XCTAssertTrue(message.contains("limit"))
        XCTAssertFalse(retryable)
    }

    func testPermissionGrantedReExecutes() async {
        let history = AgentHistory()
        let executor = ScriptedExecutor([
            "contacts_search": [.needsPermission("contacts"), .success("2 contacts found")],
        ])
        let llm = FakeLlmClient([
            toolTurn(.toolUse(id: "t1", name: "contacts_search", input: [:])),
            textTurn("Found them."),
        ])
        let loop = AgentLoop(llm: llm, executor: executor)

        let asked = Asked()
        let events = await collect(loop, history: history, userText: "find mom") { permission in
            await asked.set(permission)
            return true
        }

        await XCTAssertEqualAsync(await asked.value, "contacts")
        await XCTAssertEqualAsync(await executor.executed.count, 2) // pre + post grant
        guard case let .toolResults(results) = history.messages[2] else { return XCTFail() }
        XCTAssertEqual(results.single?.text, "2 contacts found")
        XCTAssertEqual(results.single?.isError, false)
        // NeedsPermission then Success → two ToolResultReady for t1
        XCTAssertEqual(events.filter { if case .toolResultReady("t1", _, _) = $0 { return true }; return false }.count, 2)
    }

    func testPermissionDeniedSendsErrorResult() async {
        let history = AgentHistory()
        let executor = ScriptedExecutor(["contacts_search": [.needsPermission("contacts")]])
        let llm = FakeLlmClient([
            toolTurn(.toolUse(id: "t1", name: "contacts_search", input: [:])),
            textTurn("Understood, no access."),
        ])
        let loop = AgentLoop(llm: llm, executor: executor)

        _ = await collect(loop, history: history, userText: "find mom") { _ in false }

        guard case let .toolResults(results) = history.messages[2], let result = results.single else { return XCTFail() }
        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.text.contains("declined"))
        await XCTAssertEqualAsync(await executor.executed.count, 1) // no re-execute on deny
    }

    func testFailedFirstRequestLeavesHistoryUntouched() async {
        let history = AgentHistory()
        let loop = AgentLoop(llm: FakeLlmClient([[.failed(message: "network", retryable: true)]]), executor: ScriptedExecutor())

        let events = await collect(loop, history: history, userText: "hi")

        XCTAssertEqual(history.messages.count, 0)
        XCTAssertEqual(events, [.error(message: "network", retryable: true)])
    }

    func testCancellationMidStreamLeavesNoHalfEcho() async {
        let history = AgentHistory()
        let loop = AgentLoop(llm: HangingLlmClient(), executor: ScriptedExecutor())

        let task = Task {
            await loop.run(history: history, userText: "hi", tools: [], model: .opus, awaitPermission: { _ in true }, onEvent: { _ in })
        }
        try? await Task.sleep(for: .milliseconds(120)) // the delta delivers; the fake then hangs
        task.cancel()
        await task.value

        // User message added; no assistant echo because the turn never completed.
        XCTAssertEqual(history.messages.count, 1)
        if case .user = history.messages.first {} else { XCTFail("expected only the user message") }
    }
}

// MARK: - async assert + tiny helpers

private func XCTAssertEqualAsync<T: Equatable>(_ a: @autoclosure () async -> T, _ b: T, file: StaticString = #filePath, line: UInt = #line) async {
    let value = await a()
    XCTAssertEqual(value, b, file: file, line: line)
}

private actor Asked {
    private(set) var value: String?
    func set(_ v: String) { value = v }
}

private extension Array {
    var single: Element? { count == 1 ? first : nil }
}
