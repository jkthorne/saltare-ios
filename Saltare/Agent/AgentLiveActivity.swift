import Foundation
import ActivityKit
import SaltareAgent

/// Drives the agent-turn Live Activity (Lock Screen + Dynamic Island). The
/// `AgentSessionModel` calls `update(...)` on every phase change and `end()` when
/// the turn settles. A no-op when the user has Live Activities disabled.
///
/// Deliberately NOT `@MainActor`: `Activity.update`/`end` are nonisolated async,
/// so awaiting them from an actor would require sending the (non-`Sendable`)
/// `Activity` across the isolation boundary. Keeping this nonisolated avoids that;
/// the lone stored handle is guarded by a lock.
final class AgentLiveActivity: @unchecked Sendable {
    private let lock = NSLock()
    private var activity: Activity<AgentActivityAttributes>?

    /// Reflect the current phase. Starts the activity on the first active phase,
    /// updates it while running, and ends it when the turn is no longer active.
    func update(phase: AgentPhase, toolCount: Int, lastTool: String?) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let snapshot = AgentActivityPresentation.snapshot(phase: phase, toolCount: toolCount, lastTool: lastTool)
        let state = AgentActivityAttributes.ContentState(
            statusLabel: snapshot.statusLabel,
            detail: snapshot.detail,
            toolCount: toolCount,
            isActive: snapshot.isActive
        )

        guard snapshot.isActive else { return await end(finalState: state) }

        if let current = currentActivity() {
            await current.update(ActivityContent(state: state, staleDate: nil))
        } else {
            setActivity(try? Activity.request(
                attributes: AgentActivityAttributes(title: "AGENT"),
                content: ActivityContent(state: state, staleDate: nil)
            ))
        }
    }

    /// End the activity (turn complete / cancelled), optionally flashing a final
    /// state before it dismisses.
    func end(finalState: AgentActivityAttributes.ContentState? = nil) async {
        guard let current = currentActivity() else { return }
        setActivity(nil)
        await current.end(finalState.map { ActivityContent(state: $0, staleDate: nil) }, dismissalPolicy: .default)
    }

    // MARK: - Locked handle (sync — NSLock.unlock is unavailable from async)

    private func currentActivity() -> Activity<AgentActivityAttributes>? {
        lock.lock(); defer { lock.unlock() }
        return activity
    }

    private func setActivity(_ value: Activity<AgentActivityAttributes>?) {
        lock.lock(); activity = value; lock.unlock()
    }
}
