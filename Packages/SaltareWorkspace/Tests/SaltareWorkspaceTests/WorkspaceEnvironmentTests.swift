import XCTest
@testable import SaltareWorkspace

/// The base-URL override precedence. Cheap to test and expensive to get wrong:
/// a silently-production URL makes "why didn't my local server see that?" a very
/// long afternoon, and a silently-broken one looks like an outage.
final class WorkspaceEnvironmentTests: XCTestCase {

    func testDefaultsToProduction() {
        XCTAssertEqual(WorkspaceEnvironment.resolve(info: nil, environment: nil),
                       WorkspaceEnvironment.productionURL)
        XCTAssertEqual(WorkspaceEnvironment.productionURL.absoluteString, "https://saltare.ai")
    }

    func testInfoPlistOverridesProduction() {
        XCTAssertEqual(WorkspaceEnvironment.resolve(info: "https://staging.saltare.ai", environment: nil),
                       URL(string: "https://staging.saltare.ai")!)
    }

    func testEnvironmentWinsOverInfoPlist() {
        let resolved = WorkspaceEnvironment.resolve(info: "https://staging.saltare.ai",
                                                    environment: "http://localhost:3000")
        XCTAssertEqual(resolved, URL(string: "http://localhost:3000")!,
                       "the scheme variable is the per-run override; the plist is the target default")
    }

    func testWhitespaceIsTrimmed() {
        XCTAssertEqual(WorkspaceEnvironment.resolve(info: nil, environment: "  http://localhost:3000\n"),
                       URL(string: "http://localhost:3000")!)
    }

    func testUnusableOverridesFallBackRatherThanBreakingTheApp() {
        for junk in ["", "   ", "saltare.ai", "not a url", "/api/v1"] {
            XCTAssertEqual(WorkspaceEnvironment.resolve(info: junk, environment: nil),
                           WorkspaceEnvironment.productionURL,
                           "\(junk.debugDescription) has no scheme+host, so it cannot be a base URL")
        }
    }
}
