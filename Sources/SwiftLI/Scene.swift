//
//  Scene.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/12.
//


/// A part of a command's user interface, mirroring SwiftUI's `Scene`.
///
/// A ``Command``'s `body` is a scene. Because ``View`` refines `Scene`, any
/// view is already a scene — declare `var body: some Scene` and return a
/// view; it is presented as the command's content directly:
///
/// ```swift
/// struct Fetch: InlineCommand {
///     var body: some Scene {         // a View is a Scene
///         ProgressView("Loading", phase: 0)
///     }
/// }
/// ```
///
/// The distinction exists so that configuration that belongs to the *session*
/// rather than to any view — scene modifiers like ``Scene/readingPause(_:)``
/// — has a home: they extend `Scene`, apply once at the outermost level, and
/// never clutter the view APIs used inside `body`.
public protocol Scene {
    /// The root view this scene presents.
    ///
    /// Rendering resolves a scene to a single root view and draws it with the
    /// session's renderer. For a plain ``View`` the root is the view itself.
    ///
    /// Underscored rather than `@_spi`: the default implementation below must
    /// witness this requirement for `View` conformances declared in *other*
    /// modules, and SPI members are invisible to their conformance checking.
    func _sceneRoot() -> AnyView

    /// The session settings this scene declares (see ``SceneConfiguration``).
    /// Scene modifiers layer their changes on top of the wrapped scene's
    /// configuration; a plain ``View`` declares the defaults.
    func _sceneConfiguration() -> SceneConfiguration
}

extension View {
    /// A view presents itself as its scene root.
    public func _sceneRoot() -> AnyView {
        AnyView(erasing: self)
    }

    /// A plain view declares no session settings.
    public func _sceneConfiguration() -> SceneConfiguration {
        SceneConfiguration()
    }
}

// MARK: - SceneConfiguration

/// The session-level settings a ``Scene`` carries, collected by walking the
/// scene modifier chain from the innermost content outward.
public struct SceneConfiguration {
    /// How long an idle full-screen session stays visible before ending by
    /// itself, in seconds — `nil` uses the content-proportional default.
    var readingPause: Double? = nil

    /// The menu-bar menus declared with ``Scene/commands(content:)``, in
    /// bar order.
    var menus: [ResolvedCommandMenu] = []

    /// The default configuration: every setting deferred to the session.
    public init() {}
}

// MARK: - Scene modifiers

/// The scene a scene modifier returns: the base scene's content with one
/// configuration change layered on top.
struct ModifiedScene<Base: Scene>: Scene {
    let base: Base
    let update: (inout SceneConfiguration) -> Void

    func _sceneRoot() -> AnyView {
        base._sceneRoot()
    }

    func _sceneConfiguration() -> SceneConfiguration {
        var configuration = base._sceneConfiguration()
        update(&configuration)
        return configuration
    }
}

public extension Scene {
    /// Sets how long an idle full-screen session stays visible before it
    /// restores the screen, replacing the content-proportional default
    /// (2–10 seconds).
    ///
    /// Applies when a ``FullScreenCommand``'s default `run()` finds nothing
    /// left to do — no control, no `task`, no redraw driver. Pass `0` to
    /// restore the screen immediately. Inline sessions are unaffected: their
    /// output stays in the scrollback anyway.
    ///
    /// ```swift
    /// struct Snapshot: FullScreenCommand {
    ///     var body: some Scene {
    ///         SummaryView().readingPause(5)
    ///     }
    /// }
    /// ```
    func readingPause(_ seconds: Double) -> some Scene {
        ModifiedScene(base: self) { $0.readingPause = Swift.max(0, seconds) }
    }
}

// MARK: - SceneBuilder

/// The result builder for a ``Command``'s `body`.
///
/// A command presents exactly **one** scene, and the builder's typing
/// enforces that:
/// - Any number of *view* statements combine — with `if`/`else` and the other
///   ``ViewBuilder`` forms — into a single ``TupleView``, which is one scene.
/// - A *scene* expression (a view wearing scene modifiers such as
///   ``Scene/readingPause(_:)``) must be the block's only statement.
/// - Two scene statements, or a scene next to a view, do not compile: there
///   is no block form that accepts them.
@resultBuilder
public struct SceneBuilder {
    /// An empty block produces an ``EmptyView`` scene.
    public static func buildBlock() -> EmptyView {
        EmptyView()
    }

    /// A single view passes through unchanged.
    public static func buildBlock<Content: View>(_ content: Content) -> Content {
        content
    }

    /// Exactly one scene — scenes never sit side by side. Disfavored so a
    /// plain view keeps its view type via the overload above.
    @_disfavoredOverload
    public static func buildBlock<Content: Scene>(_ content: Content) -> Content {
        content
    }

    /// Multiple views combine into a ``TupleView`` — one scene.
    public static func buildBlock<each Content: View>(_ content: repeat each Content) -> TupleView<repeat each Content> {
        TupleView((repeat each content))
    }

    /// Produces content for an `if` statement without an `else`.
    public static func buildOptional<Content: View>(_ component: Content?) -> Content? {
        component
    }

    /// Produces content for the `true` branch of an `if`/`else`.
    public static func buildEither<TrueContent: View, FalseContent: View>(
        first component: TrueContent
    ) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(storage: .trueContent(component))
    }

    /// Produces content for the `false` branch of an `if`/`else`.
    public static func buildEither<TrueContent: View, FalseContent: View>(
        second component: FalseContent
    ) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(storage: .falseContent(component))
    }

    /// Erases content guarded by an `if #available` check.
    public static func buildLimitedAvailability<Content: View>(_ component: Content) -> AnyView {
        AnyView(component)
    }

    /// A concretely-typed view expression passes through unchanged.
    public static func buildExpression<Content: View>(_ content: Content) -> Content {
        content
    }

    /// A scene expression passes through unchanged. Disfavored so views keep
    /// their view type via the overload above.
    @_disfavoredOverload
    public static func buildExpression<Content: Scene>(_ content: Content) -> Content {
        content
    }

    /// An existential (`any View`) expression is erased to an ``AnyView``.
    @_disfavoredOverload
    public static func buildExpression(_ content: any View) -> AnyView {
        AnyView(erasing: content)
    }
}
