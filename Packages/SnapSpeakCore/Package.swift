// swift-tools-version: 6.0

import PackageDescription

let swift6: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
]

let package = Package(
    name: "SnapSpeakCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v17),
    ],
    products: [
        .library(name: "LanguageKit", targets: ["LanguageKit"]),
        .library(name: "ScoringKit", targets: ["ScoringKit"]),
        .library(name: "CompositionKit", targets: ["CompositionKit"]),
        .library(name: "SRSKit", targets: ["SRSKit"]),
        .library(name: "ContentCore", targets: ["ContentCore"]),
        .library(name: "AnalyticsCore", targets: ["AnalyticsCore"]),
        .library(name: "HabitKit", targets: ["HabitKit"]),
        .library(name: "DriveKit", targets: ["DriveKit"]),
        .executable(name: "contentlint", targets: ["contentlint"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.5.1"),
    ],
    targets: [
        .target(
            name: "LanguageKit",
            swiftSettings: swift6
        ),
        .target(
            name: "ScoringKit",
            dependencies: ["LanguageKit"],
            swiftSettings: swift6
        ),
        .target(
            name: "CompositionKit",
            dependencies: ["LanguageKit"],
            swiftSettings: swift6
        ),
        .target(
            name: "SRSKit",
            dependencies: ["LanguageKit"],
            swiftSettings: swift6
        ),
        .target(
            name: "ContentCore",
            dependencies: [
                "LanguageKit",
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: swift6
        ),
        .target(
            name: "AnalyticsCore",
            dependencies: ["LanguageKit"],
            swiftSettings: swift6
        ),
        .target(
            name: "HabitKit",
            dependencies: ["SRSKit"],
            swiftSettings: swift6
        ),
        .target(
            name: "DriveKit",
            dependencies: ["SRSKit"],
            swiftSettings: swift6
        ),
        .executableTarget(
            name: "contentlint",
            dependencies: ["ContentCore"],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "LanguageKitTests",
            dependencies: ["LanguageKit"],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "ScoringKitTests",
            dependencies: ["ScoringKit"],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "CompositionKitTests",
            dependencies: ["CompositionKit"],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "SRSKitTests",
            dependencies: ["SRSKit"],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "ContentCoreTests",
            dependencies: ["ContentCore"],
            resources: [.copy("Fixtures")],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "AnalyticsCoreTests",
            dependencies: ["AnalyticsCore"],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "HabitKitTests",
            dependencies: ["HabitKit", "SRSKit"],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "DriveKitTests",
            dependencies: ["DriveKit", "SRSKit"],
            swiftSettings: swift6
        ),
    ]
)
