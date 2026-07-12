//
//  ViewBuilder.swift
//  
//  Created by Keisuke Chinone on 2024/05/27.
//

/// A custom parameter attribute that constructs views from closures.
///
/// Mirrors SwiftUI's `ViewBuilder`: each syntactic form lowers to its own
/// structural type — multiple statements become a ``TupleView``, `if`/`else`
/// becomes a ``_ConditionalContent``, an `if` without `else` becomes an
/// `Optional`, and an empty block becomes an ``EmptyView``. ``Group`` is *not*
/// involved; it is an ordinary container built on top of this builder.
///
/// Declarations (`let`/`var`) are allowed between the view statements, and no
/// `return` is needed:
///
/// ```swift
/// var body: some View {
///     let title = "Hello"
///     Text(title).bold()
///     if verbose {
///         Text("details…")
///     }
/// }
/// ```
///
/// > Note: `for` loops are not supported — iterate with ``ForEach`` instead.
@resultBuilder
public struct ViewBuilder {
    /// An empty block produces an ``EmptyView``.
    public static func buildBlock() -> EmptyView {
        EmptyView()
    }

    /// A single view passes through unchanged.
    public static func buildBlock<Content: View>(_ content: Content) -> Content {
        content
    }

    /// Multiple views combine into a ``TupleView``, preserving each child's type.
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

    /// An existential (`any View`) expression is erased to an ``AnyView`` so it
    /// can participate in the statically-typed builder tree. Disfavored so that
    /// concretely-typed expressions keep their type via the generic overload.
    @_disfavoredOverload
    public static func buildExpression(_ content: any View) -> AnyView {
        AnyView(erasing: content)
    }
}

// MARK: - Structural builder types

/// A view produced by ``ViewBuilder`` for an `if`/`else` statement, holding
/// whichever branch was taken. Not meant to be used directly.
public struct _ConditionalContent<TrueContent: View, FalseContent: View>: View {
    enum Storage {
        case trueContent(TrueContent)
        case falseContent(FalseContent)
    }

    let storage: Storage

    /// The rendered content of the active branch; rendering is delegated to the internal render system.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        switch storage {
        case .trueContent(let content):
            return .init(storage: .trueContent(content.applyingStyle(style)))
        case .falseContent(let content):
            return .init(storage: .falseContent(content.applyingStyle(style)))
        }
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        switch storage {
        case .trueContent(let content): return content.makeNode()
        case .falseContent(let content): return content.makeNode()
        }
    }

    @_spi(RenderingInternals)
    public func _flattenedChildren() -> [any View] {
        switch storage {
        case .trueContent(let content): return content._flattenedChildren()
        case .falseContent(let content): return content._flattenedChildren()
        }
    }
}

/// `Optional` acts as a view when its wrapped type is a view: `nil` renders
/// nothing. Produced by ``ViewBuilder`` for an `if` without an `else`.
///
/// The ``Scene`` conformance must be spelled out: a conditional conformance
/// to ``View`` does not imply the inherited one.
extension Optional: Scene where Wrapped: View {}

extension Optional: View where Wrapped: View {
    /// The rendered content; produces ``EmptyView`` when the value is `nil`.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        self?.applyingStyle(style)
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        self?.makeNode() ?? .empty
    }

    @_spi(RenderingInternals)
    public func _flattenedChildren() -> [any View] {
        self?._flattenedChildren() ?? []
    }
}
