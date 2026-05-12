// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HomeFeature",
    defaultLocalization: "en",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "HomeFeature",
            targets: ["HomeFeature"]),
    ],
    dependencies: [
        .package(path: "../../Core/FMDesignSystem"),
        .package(path: "../../Core/NetworkFramework"),
        .package(path: "../../Core/PersistenceFramework"),
        .package(path: "../../Shared/SharedModels"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.0.0"),
        .package(url: "https://github.com/stripe/stripe-ios-spm", from: "24.0.0"),
    ],
    targets: [
        .target(
            name: "HomeFeature",
            dependencies: [
                "FMDesignSystem",
                "NetworkFramework",
                "PersistenceFramework",
                "SharedModels",
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "StripePaymentSheet", package: "stripe-ios-spm"),
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "HomeFeatureTests",
            dependencies: ["HomeFeature"]),
    ]
)
