// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PlayerFeature",
    defaultLocalization: "en",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "PlayerFeature",
            targets: ["PlayerFeature"]),
    ],
    dependencies: [
        .package(path: "../../Core/FMDesignSystem"),
        .package(path: "../../Core/NetworkFramework"),
        .package(path: "../../Core/PersistenceFramework"),
        .package(path: "../../Shared/SharedModels"),
        .package(path: "../AdminFeature"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.0.0"),
        .package(url: "https://github.com/stripe/stripe-ios-spm", from: "24.0.0"),
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.5.0"),
    ],
    targets: [
        .target(
            name: "PlayerFeature",
            dependencies: [
                "FMDesignSystem",
                "NetworkFramework",
                "PersistenceFramework",
                "SharedModels",
                "AdminFeature",
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "StripePaymentSheet", package: "stripe-ios-spm"),
                .product(name: "Lottie", package: "lottie-spm"),
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PlayerFeatureTests",
            dependencies: ["PlayerFeature", "PersistenceFramework"]),
    ]
)
