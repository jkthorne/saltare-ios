import Foundation
@testable import SaltareKit

/// Mirrors the Android `FakeAppRepository.app(...)` helper: a minimal entry
/// whose id == label, so distinct labels get distinct frecency keys.
func app(_ label: String) -> AppEntry {
    AppEntry(id: label, label: label)
}
