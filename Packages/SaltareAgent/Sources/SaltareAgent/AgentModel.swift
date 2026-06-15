import Foundation

/// User-selectable Claude models. IDs are the exact API aliases — never append
/// date suffixes. Adaptive (extended) thinking on Opus/Sonnet, omitted on Haiku.
public enum AgentModel: String, Sendable, CaseIterable {
    case opus
    case sonnet
    case haiku

    public var id: String {
        switch self {
        case .opus: "claude-opus-4-8"
        case .sonnet: "claude-sonnet-4-6"
        case .haiku: "claude-haiku-4-5"
        }
    }

    public var label: String {
        switch self {
        case .opus: "Opus 4.8"
        case .sonnet: "Sonnet 4.6"
        case .haiku: "Haiku 4.5"
        }
    }

    public var supportsAdaptiveThinking: Bool {
        switch self {
        case .opus, .sonnet: true
        case .haiku: false
        }
    }

    /// Cycle to the next model (the settings toggle).
    public func cycled() -> AgentModel {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    public static func from(id: String?) -> AgentModel? {
        allCases.first { $0.id == id }
    }
}
