//
//  Frame.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

import Foundation

/// A flexible extent for a frame's `maxWidth` / `maxHeight`.
///
/// Only ``infinity`` is modelled: it fills the width (or height) the parent
/// proposes, falling back to the terminal size at the top level.
public enum FrameExtent: Equatable, Sendable {
    /// Fill the available space.
    case infinity
}

/// A view that constrains its content to a fixed or flexible size.
///
/// Create one with the ``View/frame(width:height:alignment:)`` and
/// ``View/frame(maxWidth:maxHeight:alignment:)`` modifiers rather than directly.
///
/// A frame proposes its resolved width down to its content, so ``Text`` inside
/// a width-constrained frame wraps to that width. When the frame is larger than
/// its content the content is positioned by `alignment`; when it is smaller the
/// content is clipped (keeping the aligned edge).
///
/// ```swift
/// Text("A long paragraph that will wrap to the box width…")
///     .frame(width: 30, alignment: .topLeading)
/// ```
public struct FrameView: View, @unchecked Sendable {
    private let wrapped: any View
    private let width: Int?
    private let height: Int?
    private let fillWidth: Bool
    private let fillHeight: Bool
    private let alignment: Alignment

    init(wrapped: any View, width: Int?, height: Int?, fillWidth: Bool, fillHeight: Bool, alignment: Alignment) {
        self.wrapped = wrapped
        self.width = width
        self.height = height
        self.fillWidth = fillWidth
        self.fillHeight = fillHeight
        self.alignment = alignment
    }

    public var body: some View { Group(contents: []) }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        .frame(width: width, height: height, fillWidth: fillWidth, fillHeight: fillHeight, alignment: alignment, child: wrapped.makeNode())
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
    func frame(width: Int? = nil, height: Int? = nil, alignment: Alignment = .center) -> FrameView {
        FrameView(wrapped: self, width: width, height: height, fillWidth: false, fillHeight: false, alignment: alignment)
    }

    /// Expands this view to fill the proposed (or terminal) extent.
    ///
    /// Pass `.infinity` to fill; `nil` leaves that dimension sized to content.
    ///
    /// - Parameters:
    ///   - maxWidth: `.infinity` to fill the available width, else `nil`.
    ///   - maxHeight: `.infinity` to fill the available height, else `nil`.
    ///   - alignment: How the content sits within the box. Defaults to `.center`.
    func frame(maxWidth: FrameExtent? = nil, maxHeight: FrameExtent? = nil, alignment: Alignment = .center) -> FrameView {
        FrameView(wrapped: self, width: nil, height: nil, fillWidth: maxWidth == .infinity, fillHeight: maxHeight == .infinity, alignment: alignment)
    }
}

// MARK: - lineLimit

/// A view that caps how many visual lines its text content renders.
///
/// Create one with ``View/lineLimit(_:)``.
public struct LineLimitView: View, @unchecked Sendable {
    private let wrapped: any View
    private let limit: Int?

    init(wrapped: any View, limit: Int?) {
        self.wrapped = wrapped
        self.limit = limit
    }

    public var body: some View { Group(contents: []) }

    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        .lineLimit(limit, child: wrapped.makeNode())
    }
}

public extension View {
    /// Limits the number of visual lines the view's text renders.
    ///
    /// When wrapping (inside a width-constrained ``FrameView``) or explicit
    /// newlines produce more lines than `limit`, the last kept line is
    /// truncated with an ellipsis. Pass `nil` to remove any limit.
    ///
    /// - Parameter limit: The maximum number of lines, or `nil` for no limit.
    func lineLimit(_ limit: Int?) -> LineLimitView {
        LineLimitView(wrapped: self, limit: limit)
    }
}
