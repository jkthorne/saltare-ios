import Foundation

/// Manual dependency-injection container, mirroring the Android `AppGraph` on
/// the Application — no Hilt/Swinject equivalent, just plain construction.
/// Held by `SaltareApp` and handed to screens explicitly. Immutable + holds
/// only `Sendable` dependencies, so it crosses into view initializers freely.
final class AppGraph: Sendable {
    let search: SearchProviding

    init(search: SearchProviding = SearchEngine()) {
        self.search = search
    }
}
