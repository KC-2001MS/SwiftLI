//
//  Border.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/08.
//


/// A modifier that draws a box of Unicode box-drawing characters around a view.
struct BorderModifier: ViewModifier {
    let box: BorderStyle
    let style: TextStyle
    let fill: TextStyle

    func node(for content: RenderNode) -> RenderNode {
        .border(style: style.resolving(), fill: fill.resolving(), box: box, child: content)
    }

    /// The box occupies one column on each side of the content.
    func adjustEnvironment(_ values: inout EnvironmentValues) {
        values.maxWidth = Swift.max(0, values.maxWidth - 2)
    }
}

// MARK: - border modifier on View

public extension View {

    /// Draws a box around this view using the given ``BorderStyle``.
    ///
    /// The box is drawn one cell outside the view's content on every side, so
    /// the content is never clipped. Combine with ``padding(_:_:)`` to inset the
    /// content from the border.
    ///
    /// ```swift
    /// Text("Rounded box")
    ///     .padding()
    ///     .border(.rounded, color: .green)
    /// ```
    ///
    /// - Parameters:
    ///   - style: The corner and edge glyph style. Defaults to ``BorderStyle/rounded``.
    ///   - color: An optional colour for the border glyphs. `nil` uses the
    ///     terminal's default foreground colour.
    ///   - fill: An optional colour that fills the whole box — interior,
    ///     padding, and the border cells themselves — so it reads as one solid
    ///     shape (the content inherits it so its text sits on the fill). `nil`
    ///     leaves the box transparent.
    ///
    ///     > Note: A filled box has a square silhouette even with ``BorderStyle/rounded``.
    ///     > A character cell has a single background colour, so a rounded
    ///     > *filled* corner cannot be drawn — the arc becomes a decorative glyph
    ///     > on the fill. This matches Textual, Rich, and Lipgloss. For a truly
    ///     > round silhouette, use a rounded border with no `fill` (an outline).
    /// - Returns: A view wrapped in the requested border.
    func border(_ style: BorderStyle = .rounded, color: Color? = nil, fill: Color? = nil) -> some View {
        let borderStyle = color.map { TextStyle(foreground: $0) } ?? .plain
        let fillStyle = fill.map { TextStyle(background: $0) } ?? .plain
        return modifier(BorderModifier(box: style, style: borderStyle, fill: fillStyle))
    }
}
