// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SaltareKeyboard",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "SaltareKeyboard", targets: ["SaltareKeyboard"]),
    ],
    targets: [
        // The keyboard's pure domain — no UIKit, no SwiftUI. The iOS analog of
        // the Android `:keyboard` `domain/` package (pure JVM): the input
        // reducer, the layouts, the editor-trait policy, and the autocorrect
        // engine, all testable with `swift test` (no simulator, no IME host).
        // The word list ships as a package resource so the loader is covered by
        // the same `swift test` that covers the engine reading it.
        .target(
            name: "SaltareKeyboard",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(name: "SaltareKeyboardTests", dependencies: ["SaltareKeyboard"]),
    ]
)
