// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KyaCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "KyaCore", targets: ["KyaCore"]),
        // Executable repository contract checks (Foundation only, no test
        // framework) so the app's SwiftData adapter tests run the same checks
        // as the in-memory reference implementation in KyaCoreTests.
        .library(name: "KyaCoreContracts", targets: ["KyaCoreContracts"]),
    ],
    targets: [
        .target(
            name: "KyaCore",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .target(
            name: "KyaCoreContracts",
            dependencies: ["KyaCore"],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "KyaCoreTests",
            dependencies: ["KyaCore", "KyaCoreContracts"],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
