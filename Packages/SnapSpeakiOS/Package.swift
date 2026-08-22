// swift-tools-version: 6.0

import PackageDescription

let swift6: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
]

let package = Package(
    name: "SnapSpeakiOS",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "ShadowingFeature", targets: ["ShadowingFeature"]),
        .library(name: "CompositionFeature", targets: ["CompositionFeature"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Analytics", targets: ["Analytics"]),
        .library(name: "AudioEngine", targets: ["AudioEngine"]),
        .library(name: "SpeechKit", targets: ["SpeechKit"]),
        .library(name: "ContentKit", targets: ["ContentKit"]),
        .library(name: "NotificationsKit", targets: ["NotificationsKit"]),
        .library(name: "ReviewFeature", targets: ["ReviewFeature"]),
        .library(name: "OnboardingFeature", targets: ["OnboardingFeature"]),
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
                .product(name: "HabitKit", package: "SnapSpeakCore"),
                .product(name: "SRSKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .target(
            name: "AudioEngine",
            dependencies: [
                "Analytics",
                .product(name: "DriveKit", package: "SnapSpeakCore"),
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
        .target(
            name: "ShadowingFeature",
            dependencies: [
                "Analytics",
                "AudioEngine",
                "ContentKit",
                "DesignSystem",
                "Persistence",
                "SpeechKit",
                .product(name: "ContentCore", package: "SnapSpeakCore"),
                .product(name: "LanguageKit", package: "SnapSpeakCore"),
                .product(name: "ScoringKit", package: "SnapSpeakCore"),
                .product(name: "SRSKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .target(
            name: "CompositionFeature",
            dependencies: [
                "Analytics",
                "AudioEngine",
                "ContentKit",
                "DesignSystem",
                "Persistence",
                "SpeechKit",
                .product(name: "CompositionKit", package: "SnapSpeakCore"),
                .product(name: "ContentCore", package: "SnapSpeakCore"),
                .product(name: "LanguageKit", package: "SnapSpeakCore"),
                .product(name: "SRSKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .target(
            name: "NotificationsKit",
            dependencies: [
                "Analytics",
                .product(name: "HabitKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .target(
            name: "ReviewFeature",
            dependencies: [
                "Analytics",
                "ContentKit",
                "DesignSystem",
                "Persistence",
                .product(name: "ContentCore", package: "SnapSpeakCore"),
                .product(name: "HabitKit", package: "SnapSpeakCore"),
                .product(name: "SRSKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .target(
            name: "OnboardingFeature",
            dependencies: [
                "Analytics",
                "DesignSystem",
                "NotificationsKit",
                "Persistence",
                .product(name: "HabitKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .target(
            name: "AppFeature",
            dependencies: [
                "Analytics",
                "AudioEngine",
                "CompositionFeature",
                "ContentKit",
                "DesignSystem",
                "NotificationsKit",
                "OnboardingFeature",
                "Persistence",
                "ReviewFeature",
                "ShadowingFeature",
                "SpeechKit",
                .product(name: "ContentCore", package: "SnapSpeakCore"),
                .product(name: "HabitKit", package: "SnapSpeakCore"),
                .product(name: "LanguageKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: [
                "Persistence",
                .product(name: "HabitKit", package: "SnapSpeakCore"),
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
        .testTarget(
            name: "ReviewFeatureTests",
            dependencies: [
                "Analytics",
                "ContentKit",
                "Persistence",
                "ReviewFeature",
                .product(name: "ContentCore", package: "SnapSpeakCore"),
                .product(name: "HabitKit", package: "SnapSpeakCore"),
                .product(name: "LanguageKit", package: "SnapSpeakCore"),
                .product(name: "SRSKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "NotificationsKitTests",
            dependencies: [
                "Analytics",
                "NotificationsKit",
                .product(name: "HabitKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "OnboardingFeatureTests",
            dependencies: [
                "Analytics",
                "NotificationsKit",
                "OnboardingFeature",
                "Persistence",
                .product(name: "HabitKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "CompositionFeatureTests",
            dependencies: [
                "Analytics",
                "AudioEngine",
                "CompositionFeature",
                "ContentKit",
                "Persistence",
                "SpeechKit",
                .product(name: "CompositionKit", package: "SnapSpeakCore"),
                .product(name: "ContentCore", package: "SnapSpeakCore"),
                .product(name: "LanguageKit", package: "SnapSpeakCore"),
                .product(name: "SRSKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "AppFeatureTests",
            dependencies: [
                "Analytics",
                "AppFeature",
                "NotificationsKit",
                "Persistence",
                "ReviewFeature",
                .product(name: "HabitKit", package: "SnapSpeakCore"),
                .product(name: "SRSKit", package: "SnapSpeakCore"),
            ],
            swiftSettings: swift6
        ),
    ]
)
