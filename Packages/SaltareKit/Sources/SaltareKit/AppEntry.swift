import Foundation

/// Stable identity for a launchable entry — the persistence key for frecency
/// and customizations. On Android this is `<pkg>/<class>|<serial>`; on iOS it's
/// the catalog id (a URL scheme or an internal saltare route).
public struct AppKey: Hashable, Sendable {
    public let raw: String
    public init(_ raw: String) { self.raw = raw }
}

/// A launchable entry, deliberately free of platform types so the domain stays
/// pure-Swift testable. The app target resolves [launchURL] (an external URL
/// scheme or an internal `saltare://…` route) at launch time.
///
/// iOS note: there is no equivalent of Android's full installed-app
/// enumeration — entries come from a *curated catalog* + saltare's own
/// destinations (see `AppCatalog`).
public struct AppEntry: Equatable, Sendable {
    public let id: String
    public let label: String
    public let launchURL: String?
    public let customLabel: String?

    public init(id: String, label: String, launchURL: String? = nil, customLabel: String? = nil) {
        self.id = id
        self.label = label
        self.launchURL = launchURL
        self.customLabel = customLabel
    }

    public var displayLabel: String { customLabel ?? label }
    public var key: AppKey { AppKey(id) }
}
