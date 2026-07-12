// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// swift-docc-plugin の Package.swift は Linux/Windows でコンパイル不可のため macOS のみ含める。
var _dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.0"),
]
#if os(macOS)
_dependencies.append(.package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.5.0"))
#endif

let package = Package(
    name: "SwiftLI",
    platforms: [
        // Parameter packs in generic types (TupleView) require the Swift 5.9
        // runtime, which ships with macOS 14.
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SwiftLI",
            targets: ["SwiftLI"]
        ),
        .executable(name: "sclt", targets: ["sclt"])
    ],
    dependencies: _dependencies,
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftLI",
            dependencies: [
                // InlineCommand / FullScreenCommand refine AsyncParsableCommand,
                // so a command declares a single conformance.
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "sclt",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "SwiftLI"
            ]
        ),
        // Tests use Swift Testing, which ships with the Swift 6 toolchain — no
        // package dependency is needed; `import Testing` resolves from the SDK.
        .testTarget(
            name: "SwiftLITests",
            dependencies: [
                "SwiftLI"
            ]
        ),
    ]
)
