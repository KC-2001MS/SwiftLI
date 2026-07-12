//
//  Environment.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/10.
//

import Foundation
import Observation

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
///
/// That one property makes the value a first-class citizen of the
/// environment, usable exactly like the built-in ones:
///
/// ```swift
/// // Inject for a subtree — the nearest injection wins.
/// StatusView().environment(\.verbosity, 2)
///
/// // Read anywhere below the injection; the default applies elsewhere.
/// struct StatusView: View {
///     @Environment(\.verbosity) private var verbosity
///     var body: some View { Text("verbosity: \(verbosity)") }
/// }
///
/// // Or derive from the inherited value.
/// LogView().transformEnvironment(\.verbosity) { $0 += 1 }
/// ```
///
/// ## Keyed @Observable objects
///
/// The value type is unrestricted, so a key can hold an `@Observable` model.
/// Use this instead of the type-based ``View/environment(_:)`` when the same
/// model type plays several roles and needs one slot per role:
///
/// ```swift
/// private struct UploadProgressKey: EnvironmentKey {
///     static var defaultValue: ProgressModel? { nil }
/// }
/// private struct DownloadProgressKey: EnvironmentKey {
///     static var defaultValue: ProgressModel? { nil }
/// }
///
/// extension EnvironmentValues {
///     var uploadProgress: ProgressModel? {
///         get { self[UploadProgressKey.self] }
///         set { self[UploadProgressKey.self] = newValue }
///     }
///     var downloadProgress: ProgressModel? {
///         get { self[DownloadProgressKey.self] }
///         set { self[DownloadProgressKey.self] = newValue }
///     }
/// }
/// ```
///
/// Property reads on the stored object during a render pass are
/// observation-tracked, so mutations re-render automatically — the same
/// behaviour as every other `@Observable` access.
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
///
/// The environment stores two kinds of entries:
/// - **Keyed values** — declared with an ``EnvironmentKey`` and exposed as a
///   computed property (see `EnvironmentKey` for the full recipe). Built-in
///   values like ``maxWidth`` and ``colorScheme`` use this form, and custom
///   values work identically.
/// - **Type-keyed objects** — `@Observable` objects injected with
///   ``View/environment(_:)`` and read back by their type via
///   `@Environment(MyModel.self)`, no key declaration needed.
public struct EnvironmentValues {
    private var values: [ObjectIdentifier: Any] = [:]

    /// Creates an environment holding only default values.
    public init() {}

    /// Accesses the value for a custom ``EnvironmentKey``.
    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
        get { values[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { values[ObjectIdentifier(key)] = newValue }
    }

    /// Accesses an `@Observable` object stored in the environment by its
    /// type — no ``EnvironmentKey`` needed.
    ///
    /// Inject with ``View/environment(_:)`` and read with
    /// `@Environment(MyModel.self)`. Property reads made during a render pass
    /// are observation-tracked, so mutations re-render just like any other
    /// `@Observable` access.
    public subscript<T: AnyObject & Observable>(objectType: T.Type) -> T? {
        get { values[ObjectIdentifier(objectType)] as? T }
        set { values[ObjectIdentifier(objectType)] = newValue }
    }
}

// MARK: - Built-in environment values

private struct MaxWidthKey: EnvironmentKey {
    // Read at access time so the top-level value follows terminal resizes.
    static var defaultValue: Int { TerminalSize.current.columns }
}

private struct MaxHeightKey: EnvironmentKey {
    // Read at access time so the top-level value follows terminal resizes.
    static var defaultValue: Int { TerminalSize.current.rows }
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

    /// The maximum number of rows the current view can occupy.
    ///
    /// At the top level this matches the terminal height (one row less in an
    /// inline session, where a row is reserved for the parked cursor).
    /// Vertical ``Spacer``s expand their column up to this height.
    var maxHeight: Int {
        get { self[MaxHeightKey.self] }
        set { self[MaxHeightKey.self] = newValue }
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

/// An action that ends the current rendering session, mirroring SwiftUI's
/// `DismissAction`.
///
/// Read it from the environment and call it like a function. For an
/// ``InlineCommand``/``FullScreenCommand`` session it has the same effect as
/// the user pressing <kbd>Ctrl-C</kbd>: the session tears down, the terminal
/// is restored, and the default `run()` returns. For a ``CLIApp`` it stops
/// the app's run loop.
///
/// Together with ``View/task(priority:fileID:line:column:_:)`` this lets a
/// command finish by itself when its work is done — no `run()` needed:
///
/// ```swift
/// struct Fetch: InlineCommand {
///     @Environment(\.dismiss) private var dismiss
///     let model = FetchModel()   // @Observable
///
///     var body: some Scene {
///         ProgressView(min: 0, value: .constant(model.progress), max: 1)
///             .task { [dismiss] in
///                 await model.fetch()
///                 dismiss()      // ends the session; run() returns
///             }
///     }
/// }
/// ```
public struct DismissAction: Sendable {
    /// A presentation-specific dismissal, when the action was injected by a
    /// presenter (a full-screen ``View/sheet(isPresented:id:onDismiss:content:)``
    /// closes the sheet); `nil` falls back to ending the session.
    private let handler: (@Sendable () -> Void)?

    init(handler: (@Sendable () -> Void)? = nil) {
        self.handler = handler
    }

    /// Dismisses the nearest enclosing presentation, or — outside of one —
    /// ends the current rendering session.
    public func callAsFunction() {
        if let handler {
            handler()
            return
        }
        // End a command session: the run-body wait loop polls this flag.
        BodyRenderingStore.shared.requestExit()
        // End a CLIApp runtime, if one is active instead.
        AppRuntime.shared?.stop()
    }
}

private struct DismissKey: EnvironmentKey {
    static var defaultValue: DismissAction { DismissAction() }
}

// Lets `@Environment(\.dismiss)` sit directly in an `AsyncParsableCommand`
// (which synthesises `Decodable`, and ArgumentParser decodes every stored
// property). The action is stateless, so it can be rebuilt from nothing —
// mirroring how `@FocusState` participates in decoding. Other environment
// values belong in child views, which have no `Decodable` requirement.
extension Environment: Decodable where Value == DismissAction {
    /// Creates the wrapper by decoding `\.dismiss` from the environment,
    /// enabling `@Environment(\.dismiss)` to appear directly in an
    /// `AsyncParsableCommand` without breaking its `Decodable` synthesis.
    public init(from decoder: any Decoder) throws {
        self.init(\.dismiss)
    }
}

public extension EnvironmentValues {
    /// An action that dismisses the nearest enclosing presentation, or ends
    /// the current rendering session. See ``DismissAction``.
    var dismiss: DismissAction {
        get { self[DismissKey.self] }
        set { self[DismissKey.self] = newValue }
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
///
/// ## Observable objects
///
/// An `@Observable` object injected with ``View/environment(_:)`` is read by
/// its type, without defining an ``EnvironmentKey``:
///
/// ```swift
/// @Observable final class AppModel: @unchecked Sendable { var count = 0 }
///
/// struct CounterRow: View {
///     @Environment(AppModel.self) private var model      // must be injected
///     @Environment(AppModel?.self) private var optional  // nil when absent
///
///     var body: some View {
///         Text("count: \(model.count)")   // read is observation-tracked
///     }
/// }
///
/// RootView().environment(AppModel())
/// ```
@propertyWrapper
public struct Environment<Value>: @unchecked Sendable {
    // The stored closure only captures immutable key paths or object types
    // and reads the thread-local environment stack at access time, so the
    // wrapper is safe to send across threads — this keeps views and commands
    // that hold `@Environment` properties `Sendable`, which `.task` requires.
    private let read: () -> Value

    /// Creates the wrapper for the given ``EnvironmentValues`` key path.
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.read = { EnvironmentStack.current[keyPath: keyPath] }
    }

    /// Creates the wrapper for an `@Observable` object stored in the
    /// environment by its type.
    ///
    /// The object must have been injected with ``View/environment(_:)``
    /// somewhere above this view; reading the value stops the program with a
    /// diagnostic otherwise. Use the optional variant
    /// (`@Environment(MyModel?.self)`) when the object may be absent.
    public init(_ objectType: Value.Type) where Value: AnyObject & Observable {
        self.read = {
            guard let object = EnvironmentStack.current[objectType] else {
                fatalError(
                    "No @Observable object of type \(Value.self) found. "
                    + "Inject one with .environment(_:) above the view that reads it, "
                    + "or read it as @Environment(\(Value.self)?.self) to allow nil."
                )
            }
            return object
        }
    }

    /// Creates the wrapper for an `@Observable` object that may be absent
    /// from the environment; the value is `nil` when nothing was injected.
    public init<T: AnyObject & Observable>(_ objectType: T?.Type) where Value == T? {
        self.read = { EnvironmentStack.current[T.self] }
    }

    /// The current environment value for the key path or object type this
    /// wrapper was initialised with, read from the active environment scope.
    public var wrappedValue: Value {
        read()
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

    func applyingStyle(_ style: TextStyle) -> Self {
        EnvironmentWritingView(content: content.applyingStyle(style), transform: transform)
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

    /// Stores an `@Observable` object in the environment for this view and
    /// its descendants, keyed by the object's type.
    ///
    /// Descendants read it back with `@Environment(MyModel.self)` (or the
    /// optional `@Environment(MyModel?.self)`). Property reads during the
    /// render pass are observation-tracked, so mutating the object re-renders
    /// automatically.
    ///
    /// ```swift
    /// DashboardView()
    ///     .environment(appModel)
    /// ```
    ///
    /// - Parameter object: The object to inject, or `nil` to remove one
    ///   injected further out.
    func environment<T: AnyObject & Observable>(_ object: T?) -> some View {
        EnvironmentWritingView(content: self) { $0[T.self] = object }
    }
}
