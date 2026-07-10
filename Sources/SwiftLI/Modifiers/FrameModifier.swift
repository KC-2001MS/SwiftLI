//
//  Frame.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//


/// A flexible extent for a frame's `maxWidth` / `maxHeight`.
///
/// Only ``infinity`` is modelled: it fills the width (or height) the parent
/// proposes, falling back to the terminal size at the top level.
public enum FrameExtent: Equatable, Sendable {
    /// Fill the available space.
    case infinity
}

/// A modifier that constrains a view to a fixed or flexible size.
///
/// A frame proposes its resolved width down to its content, so ``Text`` inside
/// a width-constrained frame wraps to that width. When the frame is larger than
/// its content the content is positioned by `alignment`; when it is smaller the
/// content is clipped (keeping the aligned edge).
struct FrameModifier: ViewModifier {
    let width: Int?
    let height: Int?
    let fillWidth: Bool
    let fillHeight: Bool
    let alignment: Alignment

    func node(for content: RenderNode) -> RenderNode {
        .frame(width: width, height: height, fillWidth: fillWidth, fillHeight: fillHeight, alignment: alignment, child: content)
    }

    /// A definite width pins the content's available columns to it.
    func adjustEnvironment(_ values: inout EnvironmentValues) {
        if let width {
            values.maxWidth = Swift.min(values.maxWidth, width)
        }
    }
}

// MARK: - frame modifiers on View

public extension View {

    /// Constrains this view to a fixed size.
    ///
    /// A definite `width` is proposed to the content, so text wraps to it; the
    /// content is then aligned within (and clipped to) the box. Pass `nil` for a
    /// dimension to leave it sized to the content.
    ///
    /// - Parameters:
    ///   - width: The fixed width in columns, or `nil` to size to content.
    ///   - height: The fixed height in rows, or `nil` to size to content.
    ///   - alignment: How the content sits within the box. Defaults to `.center`.
    func frame(width: Int? = nil, height: Int? = nil, alignment: Alignment = .center) -> some View {
        modifier(FrameModifier(width: width, height: height, fillWidth: false, fillHeight: false, alignment: alignment))
    }

    /// Expands this view to fill the proposed (or terminal) extent.
    ///
    /// Pass `.infinity` to fill; `nil` leaves that dimension sized to content.
    ///
    /// - Parameters:
    ///   - maxWidth: `.infinity` to fill the available width, else `nil`.
    ///   - maxHeight: `.infinity` to fill the available height, else `nil`.
    ///   - alignment: How the content sits within the box. Defaults to `.center`.
    func frame(maxWidth: FrameExtent? = nil, maxHeight: FrameExtent? = nil, alignment: Alignment = .center) -> some View {
        modifier(FrameModifier(width: nil, height: nil, fillWidth: maxWidth == .infinity, fillHeight: maxHeight == .infinity, alignment: alignment))
    }
}
