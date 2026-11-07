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
    /// A style applied to the conditional as a whole, cascaded onto the
    /// active branch when it lowers.
    var style: TextStyle = .plain

    /// A structural primitive: the active branch lowers directly, so there is
    /// no body.
    public typealias Body = Never

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        var copy = self
        copy.style = self.style.inheriting(style)
        return copy
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let node: RenderNode
        switch storage {
        // The branches get distinct identities so a `@State` inside one is
        // never handed to the other.
        case .trueContent(let content): node = content.lowered(at: 0)
        case .falseContent(let content): node = content.lowered(at: 1)
        }
        return style.isPlain ? node : node.applyingStyle(style)
    }

    /// The branches' children are keyed by branch, so state in one branch is
    /// never handed to the other when the condition flips.
    @_spi(RenderingInternals)
    public func _flattenedChildren() -> [any View] {
        let children: [any View]
        switch storage {
        case .trueContent(let content):
            children = content._flattenedChildren().enumerated().map { IdentifiedView(id: AnyHashable("true"), index: $0.offset, content: $0.element) }
        case .falseContent(let content):
            children = content._flattenedChildren().enumerated().map { IdentifiedView(id: AnyHashable("false"), index: $0.offset, content: $0.element) }
        }
        return style.isPlain ? children : children.map { $0.styled(style) }
    }
}

/// `Optional` acts as a view when its wrapped type is a view: `nil` renders
/// nothing. Produced by ``ViewBuilder`` for an `if` without an `else`.
///
/// The ``Scene`` conformance must be spelled out: a conditional conformance
/// to ``View`` does not imply the inherited one.
extension Optional: Scene where Wrapped: View {}

extension Optional: View where Wrapped: View {
    /// A structural primitive: the wrapped view (or nothing, for `nil`) lowers
    /// directly, so there is no body.
    public typealias Body = Never

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
