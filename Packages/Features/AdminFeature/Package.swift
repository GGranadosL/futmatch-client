// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AdminFeature",
    defaultLocalization: "en",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "AdminFeature",
            targets: ["AdminFeature"]),
    ],
    dependencies: [
        .package(path: "../../Core/FMDesignSystem"),
        .package(path: "../../Core/NetworkFramework"),
        .package(path: "../../Shared/SharedModels"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.0.0"),
    ],
    targets: [
        .target(
            name: "AdminFeature",
            dependencies: [
                "FMDesignSystem",
                "NetworkFramework",
                "SharedModels",
                .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),
            ]
        ),
        .testTarget(
            name: "AdminFeatureTests",
            dependencies: ["AdminFeature"]),
    ]
)
