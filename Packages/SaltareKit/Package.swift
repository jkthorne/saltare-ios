// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SaltareKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "SaltareKit", targets: ["SaltareKit"]),
    ],
    targets: [
        // Pure-Swift domain — no UIKit, no SwiftUI, no SDK types. The iOS
        // analog of the Android `:launcher` `domain/` package (pure JVM),
        // fully testable with `swift test` (no simulator).
        .target(name: "SaltareKit"),
        .testTarget(name: "SaltareKitTests", dependencies: ["SaltareKit"]),
    ]
)
