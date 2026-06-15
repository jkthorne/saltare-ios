import SaltareKit

/// Manual dependency-injection container, mirroring the Android `AppGraph` on
/// the Application — no Hilt/Swinject equivalent, just plain construction.
/// Held by `SaltareApp` and handed to screens explicitly.
///
/// `@MainActor` (its platform services touch UIKit) with a `nonisolated init`
/// so `SaltareApp` can build it as a stored property.
@MainActor
final class AppGraph {
    let search: SearchProviding
    let launcher: AppLaunching
    let frecency: FrecencyStore
    let contacts: ContactsProviding
    let pasteboard: Pasteboarding
    let clock: NowProviding
    /// The full launch catalog (builtins + externals), before installed-filtering.
    let catalog: [AppEntry]
    /// The on-device agent (registry → executor → loop → Anthropic client).
    let agent: AgentAssembly

    nonisolated init(
        search: SearchProviding = SearchEngine(),
        launcher: AppLaunching = UIKitLauncher(),
        frecency: FrecencyStore = FrecencyStore(),
        contacts: ContactsProviding = SystemContactsStore(),
        pasteboard: Pasteboarding = SystemPasteboard(),
        clock: NowProviding = SystemClock(),
        catalog: [AppEntry] = AppCatalog.builtins + AppCatalog.externalApps
    ) {
        self.search = search
        self.launcher = launcher
        self.frecency = frecency
        self.contacts = contacts
        self.pasteboard = pasteboard
        self.clock = clock
        self.catalog = catalog
        self.agent = AgentAssembly(catalog: catalog, launcher: launcher)
    }
}
