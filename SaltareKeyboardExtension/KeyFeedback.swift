import UIKit

/// Key-press feedback, in the order the system allows it.
///
/// The click is always available and honours the user's keyboard-click setting.
/// The haptic tick needs Full Access — the price iOS puts on a third-party
/// keyboard vibrating — so the keyboard asks once at launch and simply goes
/// quiet if the answer is no.
@MainActor
enum KeyFeedback {

    static var hasFullAccess = false

    private static let impact = UIImpactFeedbackGenerator(style: .light)

    static func keyPress() {
        UIDevice.current.playInputClick()
        guard hasFullAccess else { return }
        impact.impactOccurred()
    }
}
