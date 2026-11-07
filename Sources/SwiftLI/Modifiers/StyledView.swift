//
//  StyledView.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/11/08.
//

/// Carries a text style over a view that cannot carry it itself — a custom
/// composite view, or any view behind an existential — and cascades it onto
/// the view's lowered node.
///
/// The style modifiers (``View/bold()``, ``View/foregroundStyle(_:)``, …)
/// return `Self` for the rendering primitives, which store the style and
/// resolve it when they lower. A composite view has no such storage: its
/// default ``View/applyingStyle(_:)`` returns itself unchanged, which is why
/// `MyRow().bold()` used to be silently ignored. For those views the same
/// modifiers return this wrapper instead, which lowers the content and
/// applies the style to the resulting node — the cascade is the same
/// ``RenderNode/applyingStyle(_:)`` a container uses for its children, so the
/// content's own attributes still win where it set them.
///
/// The wrapper is identity-transparent: the content keeps the structural
/// identity (and so the `@State`) it would have had unwrapped.
public struct StyledView: View, @unchecked Sendable {
    let content: any View
    let style: TextStyle

    /// A rendering primitive: it lowers directly via ``makeNode()`` and has
    /// no body.
    public typealias Body = Never

    @_spi(RenderingInternals)
    public func applyingStyle(_ style: TextStyle) -> StyledView {
        StyledView(content: content, style: self.style.inheriting(style))
    }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        let node = content.makeNode()
        return style.isPlain ? node : node.applyingStyle(style.resolving())
    }

    @_spi(RenderingInternals)
    public func _flattenedChildren() -> [any View] {
        content._flattenedChildren().map { $0.styled(style) }
    }
}

extension View {
    /// Applies `style` to this view in the way the view supports: a view
    /// that carries a style (``_StyleCarryingView``) resolves it itself; any
    /// other view is wrapped in a ``StyledView`` that cascades the style onto
    /// its lowered node. Containers use this for their type-erased children
    /// so a style set on the container reaches composite children too.
    func styled(_ style: TextStyle) -> any View {
        guard !style.isPlain else { return self }
        if let carrying = self as? any _StyleCarryingView { return carrying.applyingStyle(style) }
        return StyledView(content: self, style: style)
    }
}

// MARK: - Style modifiers for composite views

public extension View {
    /// Sets the foreground color of every character in the view, mirroring
    /// SwiftUI's `foregroundStyle(_:)`.
    ///
    /// Works on any view — a custom composite view included — and after any
    /// other modifier: the style cascades onto the lowered content, where a
    /// child's own explicit style still takes precedence.
    func foregroundStyle(_ color: Color) -> some View {
        StyledView(content: self, style: TextStyle(foreground: color))
    }

    /// Sets the foreground color of every character in the view, mirroring
    /// SwiftUI's `foregroundColor(_:)`.
    func foregroundColor(_ color: Color) -> some View {
        StyledView(content: self, style: TextStyle(foreground: color))
    }

    /// Fills the background of the view's whole footprint with the given color.
    func background(_ color: Color) -> some View {
        StyledView(content: self, style: TextStyle(background: color))
    }

    /// Renders the view with bold weight.
    func bold() -> some View {
        StyledView(content: self, style: TextStyle(weight: .bold))
    }

    /// Renders the view with bold weight when `isActive` is `true`.
    func bold(_ isActive: Bool) -> some View {
        StyledView(content: self, style: isActive ? TextStyle(weight: .bold) : .plain)
    }

    /// Sets the font weight of the view.
    func fontWeight(_ weight: Weight) -> some View {
        StyledView(content: self, style: weight == .default ? .plain : TextStyle(weight: weight))
    }

    /// Renders the view in italics.
    func italic() -> some View {
        StyledView(content: self, style: TextStyle(isItalic: true))
    }

    /// Renders the view in italics when `isActive` is `true`.
    func italic(_ isActive: Bool) -> some View {
        StyledView(content: self, style: isActive ? TextStyle(isItalic: true) : .plain)
    }

    /// Underlines every character in the view.
    func underline() -> some View {
        StyledView(content: self, style: TextStyle(isUnderlined: true))
    }

    /// Underlines every character in the view when `isActive` is `true`.
    func underline(_ isActive: Bool) -> some View {
        StyledView(content: self, style: isActive ? TextStyle(isUnderlined: true) : .plain)
    }

    /// Applies a blinking effect using the given ``BlinkStyle``.
    func blink(_ style: BlinkStyle) -> some View {
        StyledView(content: self, style: style == .none ? .plain : TextStyle(blink: style))
    }

    /// Hides the view's characters while preserving its layout space.
    func hidden() -> some View {
        StyledView(content: self, style: TextStyle(isHidden: true))
    }

    /// Hides the view's characters when `isActive` is `true`.
    func hidden(_ isActive: Bool) -> some View {
        StyledView(content: self, style: isActive ? TextStyle(isHidden: true) : .plain)
    }

    /// Draws a horizontal strikethrough line through the view's characters.
    func strikethrough() -> some View {
        StyledView(content: self, style: TextStyle(isStrikethrough: true))
    }

    /// Draws a horizontal strikethrough line when `isActive` is `true`.
    func strikethrough(_ isActive: Bool) -> some View {
        StyledView(content: self, style: isActive ? TextStyle(isStrikethrough: true) : .plain)
    }

    /// Sets how the lines of multi-line text in this view align within the
    /// text's width, mirroring SwiftUI's `multilineTextAlignment(_:)`.
    ///
    /// Applies to text that wraps (to the available width or a frame) or
    /// contains newlines; a single line is unaffected.
    func multilineTextAlignment(_ alignment: TextAlignment) -> some View {
        StyledView(content: self, style: TextStyle(textAlignment: alignment))
    }

    /// Sets where text that exceeds its ``View/lineLimit(_:)`` is cut,
    /// mirroring SwiftUI's `truncationMode(_:)`.
    func truncationMode(_ mode: Text.TruncationMode) -> some View {
        StyledView(content: self, style: TextStyle(truncationMode: mode))
    }
}

public extension View where Self: _StyleCarryingView {
    /// Sets how wrapped lines align within the text's width (primitive form).
    func multilineTextAlignment(_ alignment: TextAlignment) -> Self {
        applyingStyle(TextStyle(textAlignment: alignment))
    }

    /// Sets where a line-limited text is cut (primitive form).
    func truncationMode(_ mode: Text.TruncationMode) -> Self {
        applyingStyle(TextStyle(truncationMode: mode))
    }
}
