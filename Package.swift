// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexSwitch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CodexSwitchCore", targets: ["CodexSwitchCore"]),
        .executable(name: "CodexSwitch", targets: ["CodexSwitch"])
    ],
    targets: [
        .target(name: "CodexSwitchCore"),
        .executableTarget(
            name: "CodexSwitch",
            dependencies: ["CodexSwitchCore"]
        ),
        .testTarget(
            name: "CodexSwitchCoreTests",
            dependencies: ["CodexSwitchCore"]
        )
    ]
)
