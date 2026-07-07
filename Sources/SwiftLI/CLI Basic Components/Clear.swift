//
//  Clear.swift
//  SwiftLI
//  
//  Created by Keisuke Chinone on 8/29/24.
//

/// A view that erases all visible content from the terminal screen.
///
/// Rendering a `Clear` view sends the ANSI `ED` (Erase in Display) escape
/// sequence `\e[2J`, which clears every cell on the visible screen without
/// moving the cursor.
///
/// ```swift
/// Clear().render()   // clears the terminal
/// ```
///
/// > Important: `Clear` does not move the cursor to the home position.
/// > Combine it with other views or ANSI cursor-movement sequences if you
/// > also need to reposition the cursor.
public struct Clear: View, Sendable, Equatable {
    /// Creates a view that clears the terminal screen when rendered.
    public init() {}

    public var body: some View {
        Group(contents: [Text(header: "\u{001B}[2J", content: "")])
    }

    /// Lowers to a ``RenderNode/raw`` node carrying the ANSI clear-screen
    /// sequence, which the pipeline emits as the frame preamble before any
    /// grid content. `Clear` itself occupies no cells.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        .raw("\u{001B}[2J")
    }

    @_spi(RenderingInternals)
    public func addHeader(_ header: String) -> Self {
        return Clear()
    }
}
