import Foundation

/// One entry's launch history: how often, and how recently.
public struct LaunchRecord: Equatable, Sendable {
    public let count: Int
    public let lastLaunchMs: Int64
    public init(count: Int, lastLaunchMs: Int64) {
        self.count = count
        self.lastLaunchMs = lastLaunchMs
    }
}

/// Frequency × recency ranking from self-tracked launches (the command surface
/// IS the launch path, so no usage-stats entitlement needed). Decay is computed
/// at read time from the stored timestamp — nothing rewrites the store on a
/// schedule. Time enters as epoch millis to keep this pure. Ported 1:1 from the
/// Android `:launcher` `Frecency`.
public enum Frecency {

    public static let halfLifeDays = 14.0
    public static let maxTracked = 100
    private static let dayMs = 86_400_000.0

    /// `count × 2^(−ageDays/14)`. Clock skew (future timestamps) clamps to no decay.
    public static func score(_ record: LaunchRecord, nowMs: Int64) -> Double {
        if record.count <= 0 { return 0 }
        let ageDays = Double(max(0, nowMs - record.lastLaunchMs)) / dayMs
        return Double(record.count) * pow(2.0, -ageDays / halfLifeDays)
    }

    /// Stable reorder by descending score: unlaunched (zero-score) entries keep
    /// their input order, after every scored entry.
    public static func order(_ apps: [AppEntry], stats: [AppKey: LaunchRecord], nowMs: Int64) -> [AppEntry] {
        if stats.isEmpty { return apps }
        return apps.enumerated().sorted { a, b in
            let sa = stats[a.element.key].map { score($0, nowMs: nowMs) } ?? 0
            let sb = stats[b.element.key].map { score($0, nowMs: nowMs) } ?? 0
            return sa != sb ? sa > sb : a.offset < b.offset
        }.map { $0.element }
    }

    /// One more launch for [key]. Prunes the lowest-scoring entries past
    /// [maxTracked] so the store stays bounded; uninstalled entries decay out.
    public static func record(_ stats: [AppKey: LaunchRecord], key: AppKey, nowMs: Int64) -> [AppKey: LaunchRecord] {
        let count = max(0, stats[key]?.count ?? 0)
        let next = count == Int.max ? count : count + 1
        var updated = stats
        updated[key] = LaunchRecord(count: next, lastLaunchMs: nowMs)
        if updated.count <= maxTracked { return updated }
        let kept = updated.sorted { score($0.value, nowMs: nowMs) > score($1.value, nowMs: nowMs) }
            .prefix(maxTracked)
        return Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
    }
}
