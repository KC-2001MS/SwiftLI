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

    public var horizontal: Horizontal
    public var vertical: Vertical

    public init(horizontal: Horizontal, vertical: Vertical) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    public static let topLeading     = Alignment(horizontal: .leading, vertical: .top)
    public static let top            = Alignment(horizontal: .center,  vertical: .top)
    public static let topTrailing    = Alignment(horizontal: .trailing, vertical: .top)
    public static let leading        = Alignment(horizontal: .leading, vertical: .center)
    public static let center         = Alignment(horizontal: .center,  vertical: .center)
    public static let trailing       = Alignment(horizontal: .trailing, vertical: .center)
    public static let bottomLeading  = Alignment(horizontal: .leading, vertical: .bottom)
    public static let bottom         = Alignment(horizontal: .center,  vertical: .bottom)
    public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)
}
