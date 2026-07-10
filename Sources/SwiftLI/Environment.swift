//
//  Environment.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/10.
//

import Foundation

// MARK: - EnvironmentKey

/// A key for accessing values in the environment, mirroring SwiftUI's
/// `EnvironmentKey`.
///
/// Define custom environment values by declaring a key with a default, then
/// exposing it as a computed property on ``EnvironmentValues``:
///
/// ```swift
/// private struct VerbosityKey: EnvironmentKey {
///     static var defaultValue: Int { 0 }
/// }
///
/// extension EnvironmentValues {
///     var verbosity: Int {
///         get { self[VerbosityKey.self] }
///         set { self[VerbosityKey.self] = newValue }
///     }
/// }
/// ```
public protocol EnvironmentKey {
    /// The type of the environment value.
    associatedtype Value

    /// The value used when nothing was injected for this key.
    static var defaultValue: Value { get }
}

// MARK: - EnvironmentValues

/// A collection of environment values propagated down the view tree,
/// mirroring SwiftUI's `EnvironmentValues`.
///
/// Read values with the ``Environment`` property wrapper; inject them for a
/// subtree with ``View/environment(_:_:)``. Values are scoped: an injection
/// affects only the view it is applied to and that view's descendants, and
/// the nearest injection wins.
public struct EnvironmentValues {
    private var values: [ObjectIdentifier: Any] = [:]

    /// Creates an environment holding only default values.
    public init() {}

    /// Accesses the value for a custom ``EnvironmentKey``.
    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
        get { values[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { values[ObjectIdentifier(key)] = newValue }
    }
}

// MARK: - Built-in environment values

private struct MaxWidthKey: EnvironmentKey {
    // Read at access time so the top-level value follows terminal resizes.
    static var defaultValue: Int { TerminalSize.current.columns }
}

private struct ColorSchemeKey: EnvironmentKey {
    static var defaultValue: ColorScheme { ColorSchemeDetector.detected }
}

public extension EnvironmentValues {
    /// The maximum number of columns the current view can occupy.
    ///
    /// At the top level this matches the terminal width. Width-constraining
    /// modifiers narrow it on the way down: inside `.frame(width: 30)` it is
    /// `30`; a `.padding()`, `.border(...)`, or `.shadow()` subtracts the
    /// columns it consumes.
    var maxWidth: Int {
        get { self[MaxWidthKey.self] }
        set { self[MaxWidthKey.self] = newValue }
    }

    /// Whether the terminal has a dark or light background.
    ///
    /// Detected once from the `COLORFGBG` environment variable that many
    /// terminals export (falling back to ``ColorScheme/dark``, by far the most
    /// common terminal appearance). Override it for a subtree with
    /// `.environment(\.colorScheme, .light)`.
    var colorScheme: ColorScheme {
        get { self[ColorSchemeKey.self] }
        set { self[ColorSchemeKey.self] = newValue }
    }
}

/// Detects the terminal's colour scheme from the `COLORFGBG` convention
/// (`"foreground;background"`, exported by iTerm2, rxvt, and others): a low
/// background palette index means a dark background.
enum ColorSchemeDetector {
    static let detected: ColorScheme = {
        if let value = ProcessInfo.processInfo.environment["COLORFGBG"],
           let background = value.split(separator: ";").last,
           let index = Int(background) {
            return (index == 7 || index >= 9) ? .light : .dark
        }
        return .dark
    }()
}

// MARK: - Environment stack

/// The stack of environment scopes for the render pass running on the current
/// thread.
///
/// `makeNode()` walks the view tree synchronously, so a plain thread-local
/// stack gives every view exactly the values its ancestors injected: scope
/// writers push a modified copy around their content's lowering, and
/// ``Environment`` reads the top of the stack.
enum EnvironmentStack {
    private static let key = "SwiftLI.EnvironmentValues.stack"

    /// The environment visible at the current point of the tree walk.
    static var current: EnvironmentValues {
        stack.last ?? EnvironmentValues()
    }

    private static var stack: [EnvironmentValues] {
        get { Thread.current.threadDictionary[key] as? [EnvironmentValues] ?? [] }
        set { Thread.current.threadDictionary[key] = newValue }
    }

    /// Runs `body` with `values` as the current environment.
    static func with<T>(_ values: EnvironmentValues, perform body: () throws -> T) rethrows -> T {
        stack.append(values)
        defer { stack.removeLast() }
        return try body()
    }
}

// MARK: - @Environment

/// A property wrapper that reads a value from the current view's environment,
/// mirroring SwiftUI's `@Environment`.
///
/// ```swift
/// struct StatusRow: View {
///     @Environment(\.maxWidth) var maxWidth
///     @Environment(\.colorScheme) var colorScheme
///
///     var body: some View {
///         Text("width: \(maxWidth)")
///             .forgroundColor(colorScheme == .dark ? .white : .black)
///     }
/// }
/// ```
///
/// The value reflects the scope the view is rendered in: reading `\.maxWidth`
/// at the top level of a command yields the terminal width, while the same
/// read inside `.frame(width: 30)` yields `30`.
@propertyWrapper
public struct Environment<Value> {
    private let keyPath: KeyPath<EnvironmentValues, Value>

    /// Creates the wrapper for the given ``EnvironmentValues`` key path.
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: Value {
        EnvironmentStack.current[keyPath: keyPath]
    }
}

// MARK: - environment modifier

/// The view produced by ``View/environment(_:_:)``: pushes a modified
/// environment around its content's lowering.
struct EnvironmentWritingView: View, @unchecked Sendable {
    let content: any View
    let transform: (inout EnvironmentValues) -> Void

    var body: some View {
        EmptyView()
    }

    func addHeader(_ header: String) -> Self {
        EnvironmentWritingView(content: content.addHeader(header), transform: transform)
    }

    func makeNode() -> RenderNode {
        var values = EnvironmentStack.current
        transform(&values)
        return EnvironmentStack.with(values) {
            content.makeNode()
        }
    }
}

public extension View {
    /// Sets an environment value for this view and its descendants.
    ///
    /// ```swift
    /// SettingsScreen()
    ///     .environment(\.colorScheme, .light)
    /// ```
    ///
    /// The nearest injection wins: a value set deeper in the tree overrides
    /// one set further out.
    func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> some View {
        EnvironmentWritingView(content: self) { $0[keyPath: keyPath] = value }
    }

    /// Transforms an environment value for this view and its descendants.
    func transformEnvironment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, transform: @escaping (inout V) -> Void) -> some View {
        EnvironmentWritingView(content: self) { transform(&$0[keyPath: keyPath]) }
    }
}
