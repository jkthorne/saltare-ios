import Foundation

/// Injected time source — keeps frecency deterministic in tests (mirrors the
/// Android injected `java.time.Clock`).
protocol NowProviding: Sendable {
    var nowMs: Int64 { get }
}

struct SystemClock: NowProviding {
    var nowMs: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}
