//
//  Geometry.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

/// A position in the terminal's character grid.
///
/// The origin `(column: 0, row: 0)` is the top-left corner of the terminal.
/// Columns increase to the right; rows increase downward.
///
/// ```
/// (0,0) ──────────────── column →
///   |   Hello, SwiftLI!
///   |   [█████████░░░░░]
///  row
///   ↓
/// ```
public struct Point: Equatable, Sendable {
    /// Horizontal position (0 = leftmost column).
    public var column: Int
    /// Vertical position (0 = topmost row).
    public var row: Int

    /// Creates a point at the given column and row.
    /// - Parameters:
    ///   - column: Horizontal position (0 = leftmost column).
    ///   - row: Vertical position (0 = topmost row).
    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }

    /// The top-left origin `(0, 0)`.
    public static let zero = Point(column: 0, row: 0)
}

/// The size of a view measured in terminal character cells.
///
/// - `width`: number of columns the view occupies.
/// - `height`: number of rows the view occupies.
public struct Size: Equatable, Sendable {
    /// Width in character columns.
    public var width: Int
    /// Height in character rows.
    public var height: Int

    /// Creates a size with the given width and height.
    /// - Parameters:
    ///   - width: Number of character columns.
    ///   - height: Number of character rows.
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// A zero-size sentinel (0 × 0).
    public static let zero = Size(width: 0, height: 0)
}

/// A rectangle in the terminal's character grid.
///
/// Combines a ``Point`` origin with a ``Size``.
public struct Rect: Equatable, Sendable {
    /// The top-left corner of the rectangle.
    public var origin: Point
    /// The dimensions of the rectangle.
    public var size: Size

    /// Creates a rectangle with the given origin and size.
    /// - Parameters:
    ///   - origin: The top-left corner of the rectangle.
    ///   - size: The dimensions of the rectangle.
    public init(origin: Point, size: Size) {
        self.origin = origin
        self.size = size
    }

    /// The column of the leading edge.
    public var minColumn: Int { origin.column }
    /// The column just past the trailing edge.
    public var maxColumn: Int { origin.column + size.width }
    /// The row of the top edge.
    public var minRow: Int    { origin.row }
    /// The row just past the bottom edge.
    public var maxRow: Int    { origin.row + size.height }

    /// A zero rect at the origin.
    public static let zero = Rect(origin: .zero, size: .zero)
}
