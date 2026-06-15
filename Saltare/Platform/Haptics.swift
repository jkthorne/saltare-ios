import UIKit

/// Light haptic ticks on selection — the iOS analog of the Android launcher's
/// haptic feedback.
enum Haptics {
    @MainActor static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
