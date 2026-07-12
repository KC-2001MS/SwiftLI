//
//  Alignment.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/07.
//

/// How a child is positioned inside a larger ``View/frame(width:height:alignment:)``.
///
/// An `Alignment` combines a horizontal and a vertical component, mirroring
/// SwiftUI's `Alignment`. When a frame is bigger than its content, the content
/// is placed according to the alignment; when it is smaller, the alignment
/// chooses which part of the content is kept as it is clipped.
public struct Alignment: Equatable, Sendable {
    /// The horizontal placement of a child within its frame.
    public enum Horizontal: Equatable, Sendable { case leading, center, trailing }
    /// The vertical placement of a child within its frame.
    public enum Vertical: Equatable, Sendable { case top, center, bottom }

    /// The horizontal component of this alignment.
    public var horizontal: Horizontal
    /// The vertical component of this alignment.
    public var vertical: Vertical

    /// Creates an alignment with the given horizontal and vertical components.
    /// - Parameters:
    ///   - horizontal: The horizontal placement of the content within its frame.
    ///   - vertical: The vertical placement of the content within its frame.
    public init(horizontal: Horizontal, vertical: Vertical) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    /// An alignment that positions content at the top-leading corner.
    public static let topLeading     = Alignment(horizontal: .leading, vertical: .top)
    /// An alignment that positions content at the top-center edge.
    public static let top            = Alignment(horizontal: .center,  vertical: .top)
    /// An alignment that positions content at the top-trailing corner.
    public static let topTrailing    = Alignment(horizontal: .trailing, vertical: .top)
    /// An alignment that positions content at the center of the leading edge.
    public static let leading        = Alignment(horizontal: .leading, vertical: .center)
    /// An alignment that positions content at the center of the frame.
    public static let center         = Alignment(horizontal: .center,  vertical: .center)
    /// An alignment that positions content at the center of the trailing edge.
    public static let trailing       = Alignment(horizontal: .trailing, vertical: .center)
    /// An alignment that positions content at the bottom-leading corner.
    public static let bottomLeading  = Alignment(horizontal: .leading, vertical: .bottom)
    /// An alignment that positions content at the bottom-center edge.
    public static let bottom         = Alignment(horizontal: .center,  vertical: .bottom)
    /// An alignment that positions content at the bottom-trailing corner.
    public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)
}
/// The vertical alignment of children within an ``HStack``.
public enum VerticalAlignment: Sendable, Equatable {
    /// Align children to the top row of the stack.
    case top
    /// Align children to the bottom row of the stack.
    case bottom
}

/// The horizontal alignment of children within a ``VStack``.
public enum HorizontalAlignment: Sendable, Equatable {
    /// Align children to the leading (left) edge of the stack.
    case leading
    /// Align children to the trailing (right) edge of the stack.
    case trailing
}
