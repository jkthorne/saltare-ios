// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SaltareHUD",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SaltareHUD", targets: ["SaltareHUD"]),
    ],
    targets: [
        .target(
            name: "SaltareHUD",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "SaltareHUDTests",
            dependencies: ["SaltareHUD"]
        ),
    ]
)
