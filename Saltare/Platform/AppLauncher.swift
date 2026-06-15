import UIKit

/// Opens external apps / system URLs. `canLaunch` gates the catalog to what's
/// actually installed (iOS can't enumerate apps — each probed scheme must be
/// declared in `LSApplicationQueriesSchemes`).
protocol AppLaunching: Sendable {
    @MainActor func canLaunch(_ urlString: String) -> Bool
    @MainActor func launch(_ urlString: String)
}

struct UIKitLauncher: AppLaunching {
    @MainActor func canLaunch(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    @MainActor func launch(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
