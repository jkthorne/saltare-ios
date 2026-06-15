// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SaltareWorkspace",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "SaltareWorkspace", targets: ["SaltareWorkspace"]),
    ],
    targets: [
        // Pure-Swift client for the saltare REST API (/api/v1/*) + native device
        // auth (POST /api/v1/auth/token). Foundation-only; request building and
        // model decoding are unit-tested (live calls need a server + token).
        .target(name: "SaltareWorkspace"),
        .testTarget(name: "SaltareWorkspaceTests", dependencies: ["SaltareWorkspace"]),
    ]
)
