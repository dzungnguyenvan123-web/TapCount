// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TapCount",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "TapCountCore",
            targets: ["TapCountCore"]
        ),
        .executable(
            name: "TapCount",
            targets: ["TapCount"]
        ),
    ],
    targets: [
        .target(
            name: "TapCountCore",
            path: "Sources/TapCountCore"
        ),
        .executableTarget(
            name: "TapCount",
            dependencies: ["TapCountCore"],
            path: "Sources/TapCount"
        ),
        .testTarget(
            name: "TapCountCoreTests",
            dependencies: ["TapCountCore"],
            path: "Tests/TapCountCoreTests"
        ),
    ]
)
