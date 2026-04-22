// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "simulator-buddy",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "SimulatorBuddyCore",
            targets: ["SimulatorBuddyCore"]
        ),
        .executable(
            name: "simulator-buddy",
            targets: ["simulator-buddy"]
        ),
    ],
    targets: [
        .target(
            name: "SimulatorBuddyCore"
        ),
        .executableTarget(
            name: "simulator-buddy",
            dependencies: ["SimulatorBuddyCore"]
        ),
        .testTarget(
            name: "SimulatorBuddyCoreTests",
            dependencies: ["SimulatorBuddyCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
