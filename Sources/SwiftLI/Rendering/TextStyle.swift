//
//  TextStyle.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/12.
//

/// The structured style attributes of a rendered run of terminal cells.
///
/// `TextStyle` is the intermediate representation of *how* content is styled:
/// views and modifiers describe their intent with semantic values (a
/// ``Color``, a ``Weight``, boolean attributes) instead of raw ANSI escape
/// sequences. The rendering engine lowers a `TextStyle` to concrete escape
/// output in exactly one place (``ansiPrefix``), so no other layer of the
/// pipeline needs to build — or parse — escape sequences to reason about
/// styling.
///
/// A style is a sparse overlay: `nil` (or `false`) means "not specified", and
/// unspecified attributes inherit from the enclosing container via
/// ``inheriting(_:)``.
public struct TextStyle: Equatable, Sendable {

    /// The foreground (text) color, or `nil` to inherit.
    public var foreground: Color?

    /// The background color, or `nil` to inherit.
    public var background: Color?

    /// The font weight, or `nil` to inherit.
    public var weight: Weight?

    /// Whether the run renders in italics.
    public var isItalic: Bool

    /// Whether the run is underlined.
    public var isUnderlined: Bool

    /// The blink behaviour, or `nil` to inherit.
    public var blink: BlinkStyle?

    /// Whether the run's glyphs are hidden.
    ///
    /// Hiding is resolved by the rendering engine — hidden glyphs are drawn
    /// as spaces of the same column width — rather than by emitting the ANSI
    /// conceal attribute, whose terminal support is spotty.
    public var isHidden: Bool

    /// Whether the run is struck through.
    public var isStrikethrough: Bool

    /// The destination URL of an OSC 8 hyperlink wrapping the run, or `nil`.
    public var link: String?

    /// Creates a new `TextStyle` with the given attributes.
    ///
    /// All parameters default to their "unspecified" value (`nil` or `false`),
    /// so you only supply the attributes you want to set explicitly.
    ///
    /// - Parameters:
    ///   - foreground: The foreground (text) color, or `nil` to inherit.
    ///   - background: The background color, or `nil` to inherit.
    ///   - weight: The font weight, or `nil` to inherit.
    ///   - isItalic: Whether the run renders in italics.
    ///   - isUnderlined: Whether the run is underlined.
    ///   - blink: The blink behaviour, or `nil` to inherit.
    ///   - isHidden: Whether the run's glyphs are hidden.
    ///   - isStrikethrough: Whether the run is struck through.
    ///   - link: The destination URL of an OSC 8 hyperlink, or `nil`.
    public init(
        foreground: Color? = nil,
        background: Color? = nil,
        weight: Weight? = nil,
        isItalic: Bool = false,
        isUnderlined: Bool = false,
        blink: BlinkStyle? = nil,
        isHidden: Bool = false,
        isStrikethrough: Bool = false,
        link: String? = nil
    ) {
        self.foreground = foreground
        self.background = background
        self.weight = weight
        self.isItalic = isItalic
        self.isUnderlined = isUnderlined
        self.blink = blink
        self.isHidden = isHidden
        self.isStrikethrough = isStrikethrough
        self.link = link
    }

    /// The style that specifies nothing and inherits everything.
    public static let plain = TextStyle()

    /// `true` when no attribute is specified.
    public var isPlain: Bool { self == .plain }

    /// Resolves this style against an enclosing style.
    ///
    /// Attributes specified on `self` win; unspecified ones fall back to
    /// `outer`. This mirrors the cascade of modifiers: the innermost
    /// (first-applied) modifier takes precedence, and container styles reach
    /// leaves only where the leaf has not set its own value.
    public func inheriting(_ outer: TextStyle) -> TextStyle {
        TextStyle(
            foreground: foreground ?? outer.foreground,
            background: background ?? outer.background,
            weight: weight ?? outer.weight,
            isItalic: isItalic || outer.isItalic,
            isUnderlined: isUnderlined || outer.isUnderlined,
            blink: blink ?? outer.blink,
            isHidden: isHidden || outer.isHidden,
            isStrikethrough: isStrikethrough || outer.isStrikethrough,
            link: link ?? outer.link
        )
    }

    // MARK: - Environment resolution

    /// Returns a copy of this style with any dynamic colors resolved against
    /// the current ``EnvironmentStack`` scope.
    ///
    /// Call this inside `makeNode()` and inside `RenderNode.applyingStyle(_:)`
    /// for leaf cases — while the environment scope injected by
    /// `EnvironmentWritingView` is still on the stack — so that draw-time
    /// lowering via ``ansiPrefix`` never reads a stale or empty scope.
    func resolving() -> TextStyle {
        guard foreground != nil || background != nil else { return self }
        let scheme = EnvironmentStack.current.colorScheme
        var result = self
        result.foreground = foreground?.resolved(scheme: scheme)
        result.background = background?.resolved(scheme: scheme)
        return result
    }

    // MARK: - ANSI lowering

    /// The escape output that opens this style, emitted in a canonical order.
    ///
    /// This is the single point where style attributes become escape
    /// sequences. The rendering engine prepends it to a run's visible content
    /// and closes the run with an SGR reset. `isHidden` deliberately emits
    /// nothing — the engine blanks hidden glyphs instead.
    var ansiPrefix: String {
        var out = ""
        if let link {
            // OSC 8 "open", terminated by ST; the canvas closes each linked
            // cell so the link never leaks past the run.
            out += "\u{001B}]8;;\(link)\u{001B}\\"
        }
        if let weight, weight != .default { out += "\u{001B}[\(weight.rawValue)m" }
        if isItalic { out += "\u{001B}[3m" }
        if isUnderlined { out += "\u{001B}[4m" }
        if let blink, blink != .none { out += "\u{001B}[\(blink.rawValue)m" }
        if isStrikethrough { out += "\u{001B}[9m" }
        if let foreground { out += "\u{001B}[3\(foreground.ansi)m" }
        if let background { out += "\u{001B}[4\(background.ansi)m" }
        return out
    }
}
