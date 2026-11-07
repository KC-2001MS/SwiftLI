//
//  Shadow.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/08.
//


/// A modifier that draws a drop shadow behind a view.
struct ShadowModifier: ViewModifier {
    let style: TextStyle
    let radius: Int
    let x: Int
    let y: Int

    func node(for content: RenderNode) -> RenderNode {
        .shadow(style: style.resolving(), radius: radius, x: x, y: y, child: content)
    }

    /// The shadow's horizontal overhang consumes columns from the content's
    /// available width.
    func adjustEnvironment(_ values: inout EnvironmentValues) {
        values.maxWidth = Swift.max(0, values.maxWidth - NodeLayout.ShadowGeometry.extraWidth(radius: radius, x: x))
    }
}

// MARK: - shadow modifier on View

public extension View {

    /// Adds a shadow to this view, mirroring SwiftUI's
    /// `shadow(color:radius:x:y:)`.
    ///
    /// The shadow is a solid band of the given colour behind the view: the
    /// view's rectangle grown by `radius` cells on every side and shifted `x`
    /// columns right and `y` rows down. Only the part the view does not cover
    /// shows, so with no radius and no offset nothing is visible — exactly as
    /// in SwiftUI. A terminal cannot blur, so `radius` widens the band
    /// instead of softening it and is optional here (SwiftUI requires it).
    ///
    /// ```swift
    /// // Classic one-cell drop shadow down and to the right.
    /// Text("Card").padding().border(.white).shadow(x: 1, y: 1)
    ///
    /// // A one-cell halo on every side.
    /// Text("Card").padding().border(.white).shadow(radius: 1)
    /// ```
    ///
    /// The shadow shows best behind a bordered or background-filled view,
    /// since the terminal cannot composite through the content's transparent
    /// cells.
    ///
    /// - Parameters:
    ///   - color: The shadow's colour. Defaults to a dark grey from the
    ///     256-colour palette (index 236).
    ///   - radius: How many cells the shadow extends past the view on every
    ///     side before the offset is applied. Defaults to `0`.
    ///   - x: The horizontal offset in columns. Positive values shift right.
    ///   - y: The vertical offset in rows. Positive values shift down.
    /// - Returns: A view that draws a shadow behind itself.
    func shadow(color: Color = .eightBit(236), radius: Int = 0, x: Int = 0, y: Int = 0) -> some View {
        modifier(ShadowModifier(style: TextStyle(background: color), radius: Swift.max(0, radius), x: x, y: y))
    }
}
