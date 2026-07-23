// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FMDesignSystem",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "FMDesignSystem",
            targets: ["FMDesignSystem"])
    ],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.5.0"),
    ],
    targets: [
        .target(
            name: "FMDesignSystem",
            dependencies: [
                .product(name: "Lottie", package: "lottie-spm"),
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "FMDesignSystemTests",
            dependencies: ["FMDesignSystem"])
    ]
)
