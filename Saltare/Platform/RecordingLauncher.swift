import SaltareKit

/// The single launch choke point — every app launch from the surface goes
/// through here, recording frecency before opening (the iOS analog of Android's
/// `RecordingAppRepository`). Settings/contact launches deliberately bypass it.
@MainActor
struct RecordingLauncher {
    let launcher: AppLaunching
    let frecency: FrecencyStore

    func launch(_ app: AppEntry) {
        frecency.record(app.key)
        if let url = app.launchURL { launcher.launch(url) }
    }
}
