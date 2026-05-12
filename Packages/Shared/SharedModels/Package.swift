// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SharedModels",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "SharedModels",
            targets: ["SharedModels"])
    ],
    dependencies: [
        .package(path: "../../Core/NetworkFramework")
    ],
    targets: [
        .target(
            name: "SharedModels",
            dependencies: [
                "NetworkFramework"
            ]
        ),
        .testTarget(
            name: "SharedModelsTests",
            dependencies: ["SharedModels"]),
    ]
)
