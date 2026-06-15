import Foundation
import Contacts
import EventKit

/// Maps the agent's permission strings to iOS authorization. `granted` feeds the
/// `ToolExecutor`'s pre-check; `request` is the loop's GRANT-flow handler. The
/// strings are stable identifiers carried on the GRANT-gated `ToolSpec`s.
enum AgentPermission: String {
    case contacts
    case calendar
}

enum AgentPermissions {
    /// Synchronous status check (the executor pre-check).
    static func granted(_ permission: String) -> Bool {
        switch AgentPermission(rawValue: permission) {
        case .contacts:
            switch CNContactStore.authorizationStatus(for: .contacts) {
            case .authorized, .limited: return true
            default: return false
            }
        case .calendar:
            return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        case nil:
            return true // unknown permission → don't block (visible-intent tools)
        }
    }

    /// Requests access (the loop's `awaitPermission`); returns whether granted.
    static func request(_ permission: String) async -> Bool {
        switch AgentPermission(rawValue: permission) {
        case .contacts:
            return (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
        case .calendar:
            return (try? await EKEventStore().requestFullAccessToEvents()) ?? false
        case nil:
            return false
        }
    }
}
