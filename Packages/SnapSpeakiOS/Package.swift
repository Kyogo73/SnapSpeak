// swift-tools-version: 6.0

import PackageDescription

let swift6: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
]

let package = Package(
    name: "SnapSpeakiOS",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Analytics", targets: ["Analytics"]),
        .library(name: "AudioEngine", targets: ["AudioEngine"]),
        .library(name: "SpeechKit", targets: ["SpeechKit"]),
        .library(name: "ContentKit", targets: ["ContentKit"]),
    ],
    dependencies: [
        .package(path: "../SnapSpeakCore"),
    ],
    targets: [
        .target(
            name: "DesignSystem",
            swiftSettings: swift6
        ),
        .target(
            name: "Analytics",
            dependencies: [
                .product(name: "AnalyticsCore", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .target(
            name: "Persistence",
            dependencies: [
                .product(name: "ContentCore", package: "SnapSpeakCore"),
                .product(name: "SRSKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .target(
            name: "AudioEngine",
            dependencies: [
                "Analytics",
                .product(name: "ScoringKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .target(
            name: "SpeechKit",
            dependencies: [
                .product(name: "LanguageKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .target(
            name: "ContentKit",
            dependencies: [
                .product(name: "ContentCore", package: "SnapSpeakCore"),
                .product(name: "SRSKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: [
                "Persistence",
                .product(name: "SRSKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "ContentKitTests",
            dependencies: [
                "ContentKit",
                .product(name: "ContentCore", package: "SnapSpeakCore"),
                .product(name: "LanguageKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
    ]
)
