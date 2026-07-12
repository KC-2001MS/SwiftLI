//
//  View.swift
//
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation


/// A single-line or multi-line text view that renders styled content to the terminal.
///
/// `Text` is the fundamental building block of SwiftLI layouts. It displays a
/// plain string or a repeated character with optional styling applied via
/// modifier methods such as ``forgroundColor(_:)``, ``bold()``, or ``italic()``.
///
/// ## Creating a text view
///
/// ```swift
/// // Display a plain string
/// Text("Hello, SwiftLI!").render()
///
/// // Display a repeated character
/// Text(repeating: "-", count: 20).render()
///
/// // Display with styling
/// Text("Hello, SwiftLI!")
///     .forgroundColor(.red)
///     .bold()
///     .render()
/// ```
///
/// ## Localization
///
/// Pass a `LocalizedStringKey` to take advantage of Foundation's localization
/// pipeline. Use ``init(verbatim:)`` when you explicitly want to skip
/// localization.
///
/// ```swift
/// Text("greeting_key")           // looks up "greeting_key" in the strings table
/// Text(verbatim: "Hello!")       // always renders "Hello!" as-is
/// ```
public struct Text: View, Sendable, Equatable {
    let style: TextStyle

    let contents: Array<String>

    /// Creates a localized text view.
    ///
    /// The string is resolved through Foundation's `String(localized:)` API using
    /// the bundle and table you specify.
    ///
    /// - Parameters:
    ///   - key: The localization key.
    ///   - tableName: The `.strings` table name, or `nil` for the default table.
    ///   - bundle: The bundle containing the strings file, or `nil` for the main bundle.
    ///   - comment: A hint for translators, or `nil` to omit.
    public init(
        _ key: LocalizedStringKey,
        tableName: String? = nil,
        bundle: Bundle? = nil,
        comment: StaticString? = nil
    ) {
        self.style = .plain
        self.contents = [key.resolve(table: tableName, bundle: bundle, comment: comment)]
    }

    /// Creates a text view that displays a string exactly as given, without localization.
    ///
    /// - Parameter content: The string to display verbatim.
    public init(verbatim content: String) {
        self.style = .plain
        self.contents = [content]
    }

    /// Creates a text view from any `StringProtocol` value.
    ///
    /// - Parameter content: A string-like value to display.
    public init<S>(_ content: S) where S : StringProtocol {
        self.style = .plain
        self.contents = [String(content)]
    }

    /// Creates a text view that repeats a single character.
    ///
    /// Useful for drawing rules or decorative separators:
    ///
    /// ```swift
    /// Text(repeating: "─", count: 40).render()
    /// ```
    ///
    /// - Parameters:
    ///   - repeating: The character to repeat.
    ///   - count: The number of repetitions.
    public init(
        repeating: Character,
        count: Int
    ) {
        self.style = .plain
        self.contents = [String(repeating: repeating, count: count)]
    }

    init(
        style: TextStyle,
        repeating: Character,
        count: Int
    ) {
        self.style = style
        self.contents = [String(repeating: repeating, count: count)]
    }

    init(
        style: TextStyle,
        contents: Array<String>
    ) {
        self.style = style
        self.contents = contents
    }

    init(
        style: TextStyle = .plain,
        content: String
    ) {
        self.style = style
        self.contents = [content]
    }

    /// `Text` is a rendering leaf: it lowers directly via ``makeNode()`` and
    /// has no body.
    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        return Text(style: self.style.inheriting(style), contents: contents)
    }

    /// Lowers this text view into its intermediate representation.
    ///
    /// Instead of touching stdout directly, `Text` emits a ``RenderNode/text``
    /// leaf that the layout engine measures, positions, and later diffs
    /// against previous frames.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        .text(style: style.resolving(), contents: contents)
    }

    /// Concatenates two text views into a single run.
    ///
    /// - Warning: Deprecated. Place adjacent text views inside an ``HStack``
    ///   — which defaults to zero spacing — instead:
    ///   ```swift
    ///   HStack {
    ///       Text("Hello, ")
    ///       Text("SwiftLI").forgroundColor(.orange)
    ///   }
    ///   ```
    @available(*, deprecated, message: "Compose adjacent Text views inside an HStack (which defaults to spacing: 0) instead.")
    static func +(left: Self, right: Self) -> Self {
        // Each side's style is baked into its runs (lowered through the same
        // single point as the renderer) so the merged view keeps both styles.
        let leftContents = left.contents.map({ left.style.ansiPrefix + $0 })
        let rightContents = right.contents.map({ right.style.ansiPrefix + $0 })
        return Text(style: .plain, contents: leftContents + rightContents)
    }
}

/// A type that describes part of a terminal user interface.
///
/// Conform to `View` to build reusable UI components for command-line tools.
/// A `View` defines its content via the ``body`` property, which is composed
/// from other views using ``ViewBuilder`` syntax.
///
/// ## Minimal example
///
/// ```swift
/// struct Greeting: View {
///     var body: some View {
///         Text("Hello, SwiftLI!").bold()
///     }
/// }
///
/// Greeting().render()
/// ```
///
/// ## Rendering
///
/// Call ``render()`` on the root view to write output to `stdout`. All other
/// rendering primitives (`renderString()`, `measure()`, `draw(into:at:)`) are
/// internal implementation details used by the layout system.
///
/// ## Styling
///
/// Apply styles through the modifier methods declared in the `View`
/// extension: ``forgroundColor(_:)``, ``bold()``, ``italic()``, ``underline()``,
/// ``blink(_:)``, ``hidden()``, and ``strikethrough()``. Styles are carried
/// through the intermediate representation as structured ``TextStyle`` values;
/// the rendering engine lowers them to escape sequences only at draw time.
///
/// ## Views are scenes
///
/// `View` refines ``Scene``, so any view can stand directly as a
/// ``Command``'s `body` — the view is the scene's whole content.
public protocol View: Scene {
    /// The type of view representing the body of this view.
    associatedtype Body: View

    /// The content and behaviour of this view.
    ///
    /// Implement `body` using ``ViewBuilder`` syntax to compose child views:
    ///
    /// ```swift
    /// var body: some View {
    ///     VStack {
    ///         Text("Title").bold()
    ///         Text("Subtitle").forgroundColor(.cyan)
    ///     }
    /// }
    /// ```
    @ViewBuilder
    var body: Body { get }

    /// Renders the view to standard output.
    ///
    /// Call this on the root view of your layout to produce terminal output.
    /// For composed layouts, prefer ``HStack``, ``VStack``, or ``Group`` as
    /// the root and call `render()` on the container.
    func render()

    // MARK: - SPI: rendering infrastructure (not part of the public API)

    /// Resolves the view against an enclosing style: the view's own style
    /// attributes win, unspecified ones inherit from `style`.
    @_spi(RenderingInternals)
    func applyingStyle(_ style: TextStyle) -> Self

    /// Lowers this view into the intermediate representation (``RenderNode``).
    ///
    /// This is the single entry point every view uses to describe itself to
    /// the rendering pipeline. Leaf views (``Text``, ``Spacer``, ``Divider``)
    /// return a leaf node; containers recurse into their children. The default
    /// implementation delegates to ``body``, so composite views only need to
    /// define `body`.
    @_spi(RenderingInternals)
    func makeNode() -> RenderNode

    @_spi(RenderingInternals)
    func renderString() -> String

    @_spi(RenderingInternals)
    func measure() -> Size

    @_spi(RenderingInternals)
    func draw(into canvas: TerminalCanvas, at origin: Point)

    /// The flat list of views this view contributes to an enclosing container.
    ///
    /// Structural views produced by ``ViewBuilder`` (``TupleView``,
    /// ``_ConditionalContent``, `Optional`, ``EmptyView``) and transparent
    /// containers (``Group``, ``ForEach``) expand to their children so that
    /// containers such as ``VStack`` or ``VGrid`` see each child individually.
    /// Ordinary views contribute themselves.
    @_spi(RenderingInternals)
    func _flattenedChildren() -> [any View]
}

public extension View {
    // The default implementations below are deliberately *not* @_spi: a
    // client module that imports SwiftLI without the SPI can only satisfy the
    // SPI requirements through visible defaults — hiding these would make it
    // impossible to conform to ``View`` outside this module.
    func applyingStyle(_ style: TextStyle) -> Self {
        return self
    }

    func makeNode() -> RenderNode {
        body.makeNode()
    }

    func render() {
        // Bracket the pass so control registrations (and the sticky refocus
        // after a navigation push) resolve the same way as session renders.
        FocusCoordinator.shared.beginRenderPass()
        defer { FocusCoordinator.shared.endRenderPass() }
        let frame = NodeLayout.frame(of: makeNode())
        var out = frame.preamble
        out += frame.lines.map { $0 + "\n" }.joined()
        print(out, terminator: "")
    }

    func renderString() -> String {
        FocusCoordinator.shared.beginRenderPass()
        defer { FocusCoordinator.shared.endRenderPass() }
        return NodeLayout.frame(of: makeNode()).lines.joined(separator: "\n")
    }

    func measure() -> Size {
        NodeLayout.measure(makeNode())
    }

    func draw(into canvas: TerminalCanvas, at origin: Point) {
        NodeLayout.draw(makeNode(), into: canvas, at: origin)
    }

    func _flattenedChildren() -> [any View] {
        [self]
    }

    // MARK: - Style modifiers

    /// Applies a foreground color to every character in the view.
    ///
    /// ```swift
    /// Text("Error").forgroundColor(.red).render()
    /// ```
    func forgroundColor(_ color: Color) -> Self {
        applyingStyle(TextStyle(foreground: color))
    }

    /// Fills the background of the view's cells with the given color.
    ///
    /// ```swift
    /// Text("Highlight").background(.yellow).render()
    /// ```
    func background(_ color: Color) -> Self {
        applyingStyle(TextStyle(background: color))
    }

    /// Renders the view with bold weight.
    ///
    /// ```swift
    /// Text("Important").bold().render()
    /// ```
    func bold() -> Self {
        applyingStyle(TextStyle(weight: .bold))
    }

    /// Renders the view with bold weight when `isActive` is `true`.
    ///
    /// - Parameter isActive: When `true`, bold is applied; otherwise the view
    ///   is rendered with its default weight.
    func bold(_ isActive: Bool) -> Self {
        isActive ? bold() : self
    }

    /// Sets the font weight of the view.
    ///
    /// - Parameter weight: The desired ``Weight``. Passing `.default` leaves the
    ///   weight unchanged.
    func fontWeight(_ weight: Weight) -> Self {
        weight == .default ? self : applyingStyle(TextStyle(weight: weight))
    }

    /// Renders the view in italics.
    ///
    /// > Note: Support depends on the terminal emulator.
    func italic() -> Self {
        applyingStyle(TextStyle(isItalic: true))
    }

    /// Renders the view in italics when `isActive` is `true`.
    ///
    /// - Parameter isActive: When `true`, italic is applied.
    func italic(_ isActive: Bool) -> Self {
        isActive ? italic() : self
    }

    /// Underlines every character in the view.
    func underline() -> Self {
        applyingStyle(TextStyle(isUnderlined: true))
    }

    /// Underlines every character in the view when `isActive` is `true`.
    ///
    /// - Parameter isActive: When `true`, underline is applied.
    func underline(_ isActive: Bool) -> Self {
        isActive ? underline() : self
    }

    /// Applies a blinking effect using the given ``BlinkStyle``.
    ///
    /// - Parameter style: The blink style. Pass `.none` to disable blinking.
    func blink(_ style: BlinkStyle) -> Self {
        style == .none ? self : applyingStyle(TextStyle(blink: style))
    }

    /// Hides the view's characters while preserving its layout space.
    ///
    /// Every visible glyph is replaced with a space of the same column width,
    /// so the surrounding layout does not shift — only the characters vanish.
    /// Blank cells stay blank. Unlike the raw ANSI conceal attribute, this
    /// works consistently across terminals because the hidden cells are drawn
    /// as actual spaces.
    ///
    /// > Note: The view still occupies the same terminal columns and rows when
    /// > hidden; only the printed characters are blanked.
    func hidden() -> Self {
        applyingStyle(TextStyle(isHidden: true))
    }

    /// Hides the view's characters when `isActive` is `true`, blanking the
    /// glyphs to spaces while keeping the layout unchanged.
    ///
    /// - Parameter isActive: When `true`, the view's characters are hidden.
    func hidden(_ isActive: Bool) -> Self {
        isActive ? hidden() : self
    }

    /// Draws a horizontal strikethrough line through the view's characters.
    func strikethrough() -> Self {
        applyingStyle(TextStyle(isStrikethrough: true))
    }

    /// Draws a horizontal strikethrough line when `isActive` is `true`.
    ///
    /// - Parameter isActive: When `true`, strikethrough is applied.
    func strikethrough(_ isActive: Bool) -> Self {
        isActive ? strikethrough() : self
    }
}
