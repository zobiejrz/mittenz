// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "mittenz",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "mittenz",
            targets: ["mittenz"]
        ),
        .executable(name: "mittenz-cli", targets: ["mittenz-cli"]),
    ],
    dependencies: [
//        .package(url: "https://github.com/zobiejrz/zChessKit", exact: "1.0.0"),
//        .package(url: "https://github.com/zobiejrz/zChessKit", branch: "main"),
        .package(url: "https://github.com/zobiejrz/zChessKit", branch: "simplify"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "mittenz",
            dependencies: ["zChessKit"]
        ),
        .testTarget(
            name: "mittenzTests",
            dependencies: ["mittenz"]
        ),
        .executableTarget(
            name: "mittenz-cli",
            dependencies: ["mittenz", "zChessKit"]
        ),
    ]
)
