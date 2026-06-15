import Foundation

/// Pure fold of `AgentEvent`s into the UI transcript. The trailing
/// `agentText(streaming: true)` is the live message; tool chips are rewritten in
/// place by id. Ported 1:1 from the Android `TranscriptReducer`.
public enum TranscriptReducer {

    public static func reduce(_ transcript: [ChatMessage], _ event: AgentEvent) -> [ChatMessage] {
        switch event {
        case let .textDelta(text):
            return appendText(transcript, text)
        case let .toolCallStarted(id, name, _):
            return sealStreaming(transcript) + [.toolChip(id: id, name: name, status: .running)]
        case let .toolResultReady(id, _, outcome):
            return rewriteChip(transcript, id: id, outcome: outcome)
        case .turnComplete, .error:
            return sealStreaming(transcript)
        }
    }

    /// Cancellation path: seal any live message without emitting more.
    public static func sealAll(_ transcript: [ChatMessage]) -> [ChatMessage] {
        sealStreaming(transcript)
    }

    private static func appendText(_ transcript: [ChatMessage], _ text: String) -> [ChatMessage] {
        if case let .agentText(existing, true) = transcript.last {
            return transcript.dropLast() + [.agentText(text: existing + text, streaming: true)]
        }
        return transcript + [.agentText(text: text, streaming: true)]
    }

    private static func sealStreaming(_ transcript: [ChatMessage]) -> [ChatMessage] {
        if case let .agentText(text, true) = transcript.last {
            return transcript.dropLast() + [.agentText(text: text, streaming: false)]
        }
        return transcript
    }

    private static func rewriteChip(_ transcript: [ChatMessage], id: String, outcome: ToolOutcome) -> [ChatMessage] {
        transcript.map { message in
            guard case let .toolChip(chipId, name, _) = message, chipId == id else { return message }
            let status: ChipStatus
            switch outcome {
            case let .success(text): status = .done(text)
            case let .needsPermission(permission): status = .needsPermission(permission)
            case let .error(text): status = .failed(text)
            }
            return .toolChip(id: chipId, name: name, status: status)
        }
    }
}
