import XCTest
@testable import SaltareKit

/// Ported from the Android `:launcher` `FrecencyTest`.
final class FrecencyTests: XCTestCase {

    private let now: Int64 = 1_750_000_000_000 // fixed epoch millis — deterministic
    private let day: Int64 = 86_400_000

    private let signal = app("Signal")
    private let camera = app("Camera")
    private let maps = app("Maps")
    private lazy var apps = [camera, maps, signal] // collator order

    func testScoreIsDeterministic() {
        let record = LaunchRecord(count: 7, lastLaunchMs: now - 7 * day)
        XCTAssertEqual(Frecency.score(record, nowMs: now), Frecency.score(record, nowMs: now))
    }

    func testHalfLifeHalvesTheScore() {
        XCTAssertEqual(Frecency.score(LaunchRecord(count: 8, lastLaunchMs: now), nowMs: now), 8.0, accuracy: 1e-9)
        XCTAssertEqual(Frecency.score(LaunchRecord(count: 8, lastLaunchMs: now - 14 * day), nowMs: now), 4.0, accuracy: 1e-9)
    }

    func testRecentLaunchesOutweighStaleHighCounts() {
        let stale = Frecency.score(LaunchRecord(count: 10, lastLaunchMs: now - 60 * day), nowMs: now)
        let recent = Frecency.score(LaunchRecord(count: 5, lastLaunchMs: now - 1 * day), nowMs: now)
        XCTAssertGreaterThan(recent, stale)
    }

    func testFutureTimestampClampsToNoDecay() {
        let skewed = Frecency.score(LaunchRecord(count: 3, lastLaunchMs: now + 5 * day), nowMs: now)
        XCTAssertEqual(skewed, 3.0, accuracy: 1e-9)
        XCTAssertFalse(skewed.isNaN)
    }

    func testNonPositiveCountScoresZero() {
        XCTAssertEqual(Frecency.score(LaunchRecord(count: 0, lastLaunchMs: now), nowMs: now), 0.0)
        XCTAssertEqual(Frecency.score(LaunchRecord(count: -3, lastLaunchMs: now), nowMs: now), 0.0)
    }

    func testOrderPutsScoredAppsFirstAndKeepsUnlaunchedOrder() {
        let stats = [signal.key: LaunchRecord(count: 5, lastLaunchMs: now - day)]
        XCTAssertEqual(Frecency.order(apps, stats: stats, nowMs: now), [signal, camera, maps])
    }

    func testOrderWithEmptyStatsIsIdentity() {
        XCTAssertEqual(Frecency.order(apps, stats: [:], nowMs: now), apps)
    }

    func testOrderIsStableForEqualScores() {
        let stats = [
            camera.key: LaunchRecord(count: 2, lastLaunchMs: now - day),
            maps.key: LaunchRecord(count: 2, lastLaunchMs: now - day),
        ]
        XCTAssertEqual(Frecency.order(apps, stats: stats, nowMs: now), [camera, maps, signal])
    }

    func testRecordIncrementsCountAndUpdatesTimestamp() {
        let once = Frecency.record([:], key: signal.key, nowMs: now - day)
        let twice = Frecency.record(once, key: signal.key, nowMs: now)
        XCTAssertEqual(twice[signal.key], LaunchRecord(count: 2, lastLaunchMs: now))
    }

    func testRecordPrunesLowestScoringPastTheCap() {
        var stats: [AppKey: LaunchRecord] = [:]
        for i in 0..<Frecency.maxTracked {
            stats = Frecency.record(stats, key: AppKey("pkg\(i)/Main|0"), nowMs: now - day)
        }
        stats = Frecency.record(stats, key: AppKey("fresh/Main|0"), nowMs: now)
        XCTAssertEqual(stats.count, Frecency.maxTracked)
        XCTAssertNotNil(stats[AppKey("fresh/Main|0")])
    }

    func testRecordSaturatesAtMaxIntInsteadOfOverflowing() {
        let maxed = [signal.key: LaunchRecord(count: Int.max, lastLaunchMs: now - day)]
        let recorded = Frecency.record(maxed, key: signal.key, nowMs: now)
        XCTAssertEqual(recorded[signal.key]?.count, Int.max)
    }
}
