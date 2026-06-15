import Foundation

/// Widget kind identifiers, shared between the app (which reloads timelines) and
/// the widget extension (which declares the configurations) so they never drift.
enum SaltareWidgetKind {
    static let search = "ai.saltare.widget.search"
    static let workspace = "ai.saltare.widget.workspace"
}
