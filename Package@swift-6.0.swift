// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftLI",
    platforms: [
            .macOS(.v11),
    ],
    products: [
        .library(
            name: "SwiftLI",
            targets: ["SwiftLI"]
        ),
        .executable(name: "sclt", targets: ["sclt"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.10.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftLI"),
        .executableTarget(
            name: "sclt",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "SwiftLI"
            ]
        ),
        .testTarget(
            name: "SwiftLITests",
            dependencies: [
                .product(name: "Testing", package: "swift-testing"),
                "SwiftLI"
            ]
        ),
    ]
)
