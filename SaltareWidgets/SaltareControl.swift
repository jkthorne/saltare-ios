import WidgetKit
import SwiftUI
import AppIntents

/// Opens the containing app from a Control. Defined in the extension (the
/// control references it directly); `openAppWhenRun` brings the app to the
/// foreground, where the command surface is the front door.
struct OpenSaltareControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Open saltare"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult { .result() }
}

/// An iOS 18 Control Center / Lock Screen control that opens the universal
/// input — one of the system surfaces that recovers Android's "launcher is
/// HOME" reach.
struct SaltareControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ai.saltare.control.open") {
            ControlWidgetButton(action: OpenSaltareControlIntent()) {
                Label("saltare", systemImage: "diamond.fill")
            }
        }
        .displayName("saltare")
        .description("Open the universal input.")
    }
}
