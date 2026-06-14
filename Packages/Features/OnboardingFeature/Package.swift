// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OnboardingFeature",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "OnboardingFeature",
            targets: ["OnboardingFeature"])
    ],
    dependencies: [
        .package(path: "../../Core/NetworkFramework"),
        .package(path: "../../Core/PersistenceFramework"),
        .package(path: "../../Core/FMDesignSystem"),
        .package(path: "../../Shared/SharedModels"),
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.5.0")
    ],
    targets: [
        .target(
            name: "OnboardingFeature",
            dependencies: [
                "NetworkFramework",
                "PersistenceFramework",
                "FMDesignSystem",
                "SharedModels",
                .product(name: "Lottie", package: "lottie-spm")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "OnboardingFeatureTests",
            dependencies: ["OnboardingFeature", "PersistenceFramework"])
    ]
)
