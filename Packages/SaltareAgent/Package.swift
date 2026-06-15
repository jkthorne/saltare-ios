// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SaltareAgent",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "SaltareAgent", targets: ["SaltareAgent"]),
    ],
    targets: [
        // Pure-Swift agent core — the manual tool loop + domain model, SDK-free
        // and network-free (the Android `:agent` `domain/` + `loop/`). The
        // Anthropic client, iOS tools, and MCP land in the app target / data
        // layer (iP2.2+). Fully testable with `swift test` (no simulator).
        .target(name: "SaltareAgent"),
        .testTarget(name: "SaltareAgentTests", dependencies: ["SaltareAgent"]),
    ]
)
