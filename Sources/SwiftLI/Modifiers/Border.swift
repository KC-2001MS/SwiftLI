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

    func node(for content: RenderNode) -> RenderNode {
        .border(style: style.resolving(), fill: .plain, box: box, child: content)
    }

    /// The box occupies one column on each side of the content.
    func adjustEnvironment(_ values: inout EnvironmentValues) {
        values.maxWidth = Swift.max(0, values.maxWidth - 2)
    }
}

// MARK: - border modifier on View

public extension View {

    /// Draws a box around this view in the given colour, mirroring SwiftUI's
    /// `border(_:width:)`.
    ///
    /// The box is drawn one cell outside the view's content on every side, so
    /// the content is never clipped. Combine with ``padding(_:_:)`` to inset the
    /// content from the border, and with ``background(_:)`` to fill the box —
    /// a background applied after the border paints the whole box, border
    /// cells included, just as SwiftUI paints behind a bordered view:
    ///
    /// ```swift
    /// Text("Rounded box")
    ///     .padding()
    ///     .border(.green)
    ///
    /// Text("Filled card")
    ///     .padding()
    ///     .border(.white, style: .single)
    ///     .background(.blue)
    /// ```
    ///
    /// - Parameters:
    ///   - color: The colour of the border glyphs. Pass ``Color/primary`` for
    ///     the terminal's default foreground colour.
    ///   - style: The corner and edge glyph style, a terminal-specific
    ///     refinement of SwiftUI's line width. Defaults to
    ///     ``BorderStyle/rounded``.
    ///
    ///     > Note: A filled box has a square silhouette even with ``BorderStyle/rounded``.
    ///     > A character cell has a single background colour, so a rounded
    ///     > *filled* corner cannot be drawn — the arc becomes a decorative glyph
    ///     > on the fill. This matches Textual, Rich, and Lipgloss. For a truly
    ///     > round silhouette, use a rounded border with no background (an outline).
    /// - Returns: A view wrapped in the requested border.
    func border(_ color: Color, style: BorderStyle = .rounded) -> some View {
        modifier(BorderModifier(box: style, style: TextStyle(foreground: color)))
    }
}
