import SwiftUI
import SaltareHUD

/// The app entry point. Dark "android" theme is the system's identity (it does
/// not follow the platform appearance) — the command surface is the front door.
@main
struct SaltareApp: App {
    private let graph = AppGraph()

    var body: some Scene {
        WindowGroup {
            CommandSurfaceView(graph: graph)
                .saltareTheme(colors: .dark)
                .preferredColorScheme(.dark)
        }
    }
}
