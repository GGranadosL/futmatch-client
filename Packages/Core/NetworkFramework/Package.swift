// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NetworkFramework",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "NetworkFramework",
            targets: ["NetworkFramework"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NetworkFramework",
            dependencies: [],
            path: "Sources/NetworkFramework"
        ),
        .testTarget(
            name: "NetworkFrameworkTests",
            dependencies: ["NetworkFramework"],
            path: "Tests"
        )
    ]
)
