// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

// swift-docc-plugin's Package.swift does not compile on Linux/Windows, so it is included on macOS only.
var _dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.0"),
    // The `@State` macro (see Sources/SwiftLIMacros) is implemented with
    // swift-syntax; any release from 600 (Swift 6.0) upward works.
    .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"700.0.0"),
]
#if os(macOS)
_dependencies.append(.package(url: "https://github.com/apple/swift-docc-plugin", from: "1.5.0"))
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
        // The compiler plugin behind `@State`: it expands the attribute into
        // the lazily resolved storage, `_x`, and `$x`, as SwiftUI does since
        // Xcode 27.
        .macro(
            name: "SwiftLIMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "SwiftLI",
            dependencies: [
                // InlineCommand / FullScreenCommand refine AsyncParsableCommand,
                // so a command declares a single conformance.
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "SwiftLIMacros",
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
        .testTarget(
            name: "SwiftLIMacrosTests",
            dependencies: [
                "SwiftLIMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
