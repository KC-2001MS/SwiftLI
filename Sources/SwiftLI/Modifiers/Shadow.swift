//
//  Shadow.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/08.
//


/// A modifier that draws a drop shadow along a view's right and bottom edges.
struct ShadowModifier: ViewModifier {
    let style: TextStyle

    func node(for content: RenderNode) -> RenderNode {
        .shadow(style: style.resolving(), child: content)
    }

    /// The shadow band occupies one column to the right of the content.
    func adjustEnvironment(_ values: inout EnvironmentValues) {
        values.maxWidth = Swift.max(0, values.maxWidth - 1)
    }
}

// MARK: - shadow modifier on View

public extension View {

    /// Draws a drop shadow along this view's right and bottom edges.
    ///
    /// The shadow is a solid band of the given background colour, offset one
    /// cell down and to the right. It shows best behind a bordered or
    /// background-filled view, since the terminal cannot composite through the
    /// content's transparent cells.
    ///
    /// - Parameter color: The shadow's background colour. Defaults to a dark
    ///   grey from the 256-colour palette (index 236).
    /// - Returns: A view with a drop shadow along its right and bottom edges.
    func shadow(_ color: Color = .eight_bit(236)) -> some View {
        modifier(ShadowModifier(style: TextStyle(background: color)))
    }
}
