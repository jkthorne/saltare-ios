import Foundation

/// Where saltare lives. The app, the agent's inference proxy, the realtime
/// socket and the share extension all have to agree on this, and each of them
/// used to carry its own copy of the production URL — change the host and the
/// extension would quietly keep posting somewhere else.
///
/// Overridable, because most of the workspace features can only really be
/// exercised against a running server:
///
/// 1. `SALTARE_BASE_URL` in the environment — the simulator scheme's variable,
///    alongside the existing `SALTARE_DEMO`. Not visible to extensions, which
///    the system launches on its own.
/// 2. `SaltareWorkspaceBaseURL` in the target's Info.plist — add it under the
///    target's `info.properties` in `project.yml`; it reaches the extensions too.
/// 3. Otherwise production.
public enum WorkspaceEnvironment {
    public static let productionURL = URL(string: "https://saltare.ai")!
    public static let infoKey = "SaltareWorkspaceBaseURL"
    public static let environmentKey = "SALTARE_BASE_URL"

    public static var baseURL: URL {
        resolve(info: Bundle.main.object(forInfoDictionaryKey: infoKey) as? String,
                environment: ProcessInfo.processInfo.environment[environmentKey])
    }

    /// The precedence, pulled out so it is testable without a bundle.
    public static func resolve(info: String?, environment: String?) -> URL {
        url(from: environment) ?? url(from: info) ?? productionURL
    }

    /// A misconfigured override falls back to production rather than taking the
    /// app offline — a typo in a scheme variable should not look like an outage.
    private static func url(from raw: String?) -> URL? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty,
              let url = URL(string: trimmed), url.scheme != nil, url.host != nil else { return nil }
        return url
    }
}
