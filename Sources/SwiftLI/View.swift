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
/// modifier methods such as ``foregroundStyle(_:)``, ``bold()``, or ``italic()``.
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
///     .foregroundStyle(.red)
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

    /// The individually styled pieces of a multi-style text — one made from
    /// an `AttributedString` or by concatenating texts with `+` — or `nil`
    /// for a text with a single style. When present, `contents` is derived
    /// from the runs at lowering time.
    let runs: [TextRun]?

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
        self.runs = nil
    }

    /// Creates a text view that displays a string exactly as given, without localization.
    ///
    /// - Parameter content: The string to display verbatim.
    public init(verbatim content: String) {
        self.style = .plain
        self.contents = [content]
        self.runs = nil
    }

    /// Creates a text view from any `StringProtocol` value.
    ///
    /// - Parameter content: A string-like value to display.
    public init<S>(_ content: S) where S : StringProtocol {
        self.style = .plain
        self.contents = [String(content)]
        self.runs = nil
    }

    /// Creates a text view whose pieces carry their own styles, mirroring
    /// SwiftUI's `Text(_ attributedContent: AttributedString)`.
    ///
    /// Each run of the attributed string becomes a styled piece: the SwiftLI
    /// attributes (`foregroundColor`, `backgroundColor`, `fontWeight`,
    /// `underline`, `italic`, `strikethrough` — see
    /// `AttributeScopes.SwiftLIAttributes`) and Foundation's
    /// `inlinePresentationIntent` and `link` are honoured. The text wraps to
    /// the available width like any other, and a style applied to the whole
    /// view fills in whatever the runs leave unspecified.
    ///
    /// ```swift
    /// var summary = AttributedString("Build passed in 42s")
    /// if let range = summary.range(of: "passed") {
    ///     summary[range].foregroundColor = .green
    /// }
    /// Text(summary)
    /// ```
    public init(_ attributedContent: AttributedString) {
        let runs = attributedContent.runs.map { TextRun($0, in: attributedContent) }
        self.style = .plain
        self.contents = runs.map(\.text)
        self.runs = runs
    }

    /// Creates a text view showing a date in one of SwiftUI's `Text.DateStyle`s.
    ///
    /// `.relative`, `.offset` and `.timer` describe the interval to *now*;
    /// inside a reactive session the text refreshes itself (every minute,
    /// or every second for `.timer`) so it stays current.
    public init(_ date: Date, style: Text.DateStyle) {
        if let interval = style.refreshInterval,
           BodyRenderingStore.shared.sessionActive || AppRuntime.shared != nil {
            TimelineCoordinator.shared.arm(key: "Text.DateStyle.\(interval)", fireAt: Date().addingTimeInterval(interval))
        }
        self.style = .plain
        self.contents = [style.format(date)]
        self.runs = nil
    }

    /// Creates a text view from a value and a Foundation `FormatStyle`,
    /// mirroring SwiftUI's `Text(_:format:)`:
    ///
    /// ```swift
    /// Text(stars, format: .number.notation(.compactName))   // 12K
    /// Text(updatedAt, format: .dateTime.hour().minute())
    /// ```
    public init<F: FormatStyle>(_ input: F.FormatInput, format: F) where F.FormatOutput == String {
        self.style = .plain
        self.contents = [format.format(input)]
        self.runs = nil
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
        self.runs = nil
    }

    init(
        style: TextStyle,
        repeating: Character,
        count: Int
    ) {
        self.style = style
        self.contents = [String(repeating: repeating, count: count)]
        self.runs = nil
    }

    init(
        style: TextStyle,
        contents: Array<String>
    ) {
        self.style = style
        self.contents = contents
        self.runs = nil
    }

    init(
        style: TextStyle = .plain,
        content: String
    ) {
        self.style = style
        self.contents = [content]
        self.runs = nil
    }

    init(style: TextStyle, runs: [TextRun]) {
        self.style = style
        self.contents = runs.map(\.text)
        self.runs = runs
    }

    /// `Text` is a rendering leaf: it lowers directly via ``makeNode()`` and
    /// has no body.
    public typealias Body = Never

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> Self {
        if let runs { return Text(style: self.style.inheriting(style), runs: runs) }
        return Text(style: self.style.inheriting(style), contents: contents)
    }

    /// Lowers this text view into its intermediate representation.
    ///
    /// Instead of touching stdout directly, `Text` emits a ``RenderNode/text``
    /// leaf that the layout engine measures, positions, and later diffs
    /// against previous frames.
    ///
    /// A multi-style text lowers to a single run whose pieces carry their
    /// own escape sequences: each piece resets, then opens its style
    /// resolved against the text's overall style. The layout engine wraps
    /// such runs escape-aware, re-opening the active style on every
    /// continuation line.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let resolved = style.resolving()
        guard let runs else { return .text(style: resolved, contents: contents) }
        var composed = ""
        for run in runs {
            let runStyle = run.style.inheriting(style).resolving()
            composed += TextMetrics.reset + runStyle.ansiPrefix + run.text
        }
        return .text(style: resolved, contents: [composed])
    }

    /// The pieces of this text, each with its style, for concatenation.
    private var pieces: [TextRun] {
        runs ?? contents.map { TextRun(style: style, text: $0) }
    }

    /// Concatenates two text views, keeping each side's own style — the
    /// SwiftUI way to compose a line from differently styled pieces:
    ///
    /// ```swift
    /// Text("★ ").foregroundStyle(.yellow) + Text("\(stars)").bold()
    /// ```
    ///
    /// The result is one ``Text``: it wraps to the available width as a
    /// whole (a styled word keeps its look when it moves to the next row),
    /// and a modifier applied to it fills in what the pieces leave unset.
    public static func + (left: Text, right: Text) -> Text {
        Text(style: .plain, runs: left.pieces + right.pieces)
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
/// extension: ``foregroundStyle(_:)``, ``bold()``, ``italic()``, ``underline()``,
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
    ///         Text("Subtitle").foregroundStyle(.cyan)
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
}

// MARK: - Style modifiers (primitives)

// The rendering primitives and built-in controls (``_StyleCarryingView``)
// store a style and resolve it themselves, so their modifiers return `Self`
// (`Text("a").bold()` is still a `Text`). A composite view gets the same
// modifiers from the unconstrained extension in StyledView.swift, which
// wraps it so the style reaches its lowered content.
public extension View where Self: _StyleCarryingView {
    /// Sets the foreground color of every character in the view, mirroring
    /// SwiftUI's `foregroundStyle(_:)`.
    ///
    /// ```swift
    /// Text("Error").foregroundStyle(.red).render()
    /// ```
    func foregroundStyle(_ color: Color) -> Self {
        applyingStyle(TextStyle(foreground: color))
    }

    /// Sets the foreground color of every character in the view.
    ///
    /// This is the older SwiftUI spelling; prefer ``foregroundStyle(_:)``.
    func foregroundColor(_ color: Color) -> Self {
        foregroundStyle(color)
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

// MARK: - Primitive views

/// `Never` is a view so that primitive views — the leaves and containers the
/// rendering engine lowers itself — can declare `Body == Never`, exactly as
/// SwiftUI's primitives do. Such a view has no `body`; reading it is a
/// programming error.
extension Never: Scene {}

extension Never: View {
    public typealias Body = Never
}

public extension View where Body == Never {
    /// A primitive view is lowered by the rendering engine directly and has
    /// no body to evaluate.
    var body: Never {
        fatalError("\(Self.self) is a primitive view and has no body")
    }
}
