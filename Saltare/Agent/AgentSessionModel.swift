import Foundation
import Observation
import SaltareAgent

/// Owns one agent conversation: transcript, the running loop task, and the
/// permission round-trip bridge. The iOS analog of the Android `AgentViewModel`.
@MainActor
@Observable
final class AgentSessionModel {
    private(set) var transcript: [ChatMessage] = []
    private(set) var phase: AgentPhase = .idle
    private(set) var pendingPermission: String?
    private(set) var errorBanner: String?
    var model: AgentModel = .opus
    var input: String = ""

    private let assembly: AgentAssembly
    private let history = AgentHistory()
    private var task: Task<Void, Never>?
    private var permissionContinuation: CheckedContinuation<Bool, Never>?

    init(assembly: AgentAssembly) { self.assembly = assembly }

    var hasCredentials: Bool { assembly.hasCredentials }
    var isStreaming: Bool { task != nil }

    func submit() {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, task == nil else { return }
        guard hasCredentials else {
            errorBanner = "Sign in to saltare, or add an Anthropic API key in Agent settings."
            return
        }
        input = ""
        errorBanner = nil
        transcript.append(.user(query))
        phase = .streaming

        let stream = assembly.loop.runStream(
            history: history,
            userText: query,
            tools: assembly.tools,
            model: model,
            awaitPermission: { [weak self] permission in
                await self?.awaitPermission(permission) ?? false
            }
        )
        task = Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                transcript = TranscriptReducer.reduce(transcript, event)
                if case let .error(message, _) = event { errorBanner = message }
            }
            guard let self else { return }
            phase = errorBanner != nil ? .error : .idle
            task = nil
        }
    }

    private func awaitPermission(_ permission: String) async -> Bool {
        phase = .awaitingPermission
        pendingPermission = permission
        let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            permissionContinuation = continuation
        }
        pendingPermission = nil
        phase = .streaming
        return granted
    }

    /// GRANT tapped — request the iOS permission, then resume the held loop.
    func grantPermission() {
        guard let permission = pendingPermission else { return }
        Task { [weak self] in
            let granted = await self?.assembly.awaitPermission(permission) ?? false
            self?.resume(granted)
        }
    }

    func declinePermission() { resume(false) }

    private func resume(_ granted: Bool) {
        permissionContinuation?.resume(returning: granted)
        permissionContinuation = nil
    }

    /// Sheet dismissed: stop network work but keep the conversation.
    func cancelStreaming() {
        task?.cancel()
        task = nil
        resume(false)
        pendingPermission = nil
        transcript = TranscriptReducer.sealAll(transcript)
        if phase != .error { phase = .idle }
    }

    func cycleModel() { model = model.cycled() }
}
