// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PersistenceFramework",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "PersistenceFramework",
            targets: ["PersistenceFramework"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PersistenceFramework",
            dependencies: [],
            path: "Sources/PersistenceFramework"
        ),
        .testTarget(
            name: "PersistenceFrameworkTests",
            dependencies: ["PersistenceFramework"],
            path: "Tests"
        )
    ]
)
