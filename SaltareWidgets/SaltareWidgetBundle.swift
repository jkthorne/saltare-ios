import WidgetKit
import SwiftUI

/// The widget extension's entry point: a Home/Lock-Screen search widget plus an
/// iOS 18 Control Center control. Both open the command surface (the launcher's
/// universal input radiating onto the iOS system surfaces Android can't reach).
@main
struct SaltareWidgetBundle: WidgetBundle {
    var body: some Widget {
        SaltareSearchWidget()
        SaltareControl()
    }
}
