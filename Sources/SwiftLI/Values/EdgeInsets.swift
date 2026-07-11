//
//  EdgeInsets.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/10.
//

/// The inset space around a view, one amount per edge, mirroring SwiftUI's
/// `EdgeInsets` (measured in character cells).
///
/// ```swift
/// Text("Report")
///     .padding(EdgeInsets(top: 1, leading: 4, bottom: 0, trailing: 2))
/// ```
public struct EdgeInsets: Equatable, Sendable {
    /// Blank rows above the content.
    public var top: Int
    /// Blank columns before the content.
    public var leading: Int
    /// Blank rows below the content.
    public var bottom: Int
    /// Blank columns after the content.
    public var trailing: Int

    /// Creates insets with the given per-edge amounts (each defaults to `0`).
    public init(top: Int = 0, leading: Int = 0, bottom: Int = 0, trailing: Int = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    /// Insets of zero on every edge.
    public static let zero = EdgeInsets()

    /// Uniform insets of `length` on every edge in `edges`.
    init(edges: Edge.Set, length: Int) {
        self.top = edges.contains(.top) ? length : 0
        self.leading = edges.contains(.leading) ? length : 0
        self.bottom = edges.contains(.bottom) ? length : 0
        self.trailing = edges.contains(.trailing) ? length : 0
    }

    /// The total columns the horizontal insets consume.
    var horizontal: Int { leading + trailing }

    /// The total rows the vertical insets consume.
    var vertical: Int { top + bottom }
}
