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
    dependencies: [],
    targets: [
        .target(
            name: "FMDesignSystem",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "FMDesignSystemTests",
            dependencies: ["FMDesignSystem"])
    ]
)
