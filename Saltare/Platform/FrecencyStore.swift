import Foundation
import SaltareKit

/// Persists self-tracked launch frecency to `UserDefaults`. Corruption-tolerant:
/// a malformed blob reads as empty (the `SettingsRepository` discipline —
/// every codec tolerates corrupt tokens). Keyed by `AppKey.raw`.
final class FrecencyStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let now: NowProviding
    private let storageKey = "frecency.v1"

    init(defaults: UserDefaults = .standard, now: NowProviding = SystemClock()) {
        self.defaults = defaults
        self.now = now
    }

    func stats() -> [AppKey: LaunchRecord] { load() }

    /// The single launch choke point's write — records one more launch for `key`.
    func record(_ key: AppKey) {
        save(Frecency.record(load(), key: key, nowMs: now.nowMs))
    }

    private struct Persisted: Codable {
        let count: Int
        let last: Int64
    }

    private func load() -> [AppKey: LaunchRecord] {
        guard let data = defaults.data(forKey: storageKey),
              let raw = try? JSONDecoder().decode([String: Persisted].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.map { (AppKey($0.key), LaunchRecord(count: $0.value.count, lastLaunchMs: $0.value.last)) })
    }

    private func save(_ stats: [AppKey: LaunchRecord]) {
        let raw = Dictionary(uniqueKeysWithValues: stats.map { ($0.key.raw, Persisted(count: $0.value.count, last: $0.value.lastLaunchMs)) })
        guard let data = try? JSONEncoder().encode(raw) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
