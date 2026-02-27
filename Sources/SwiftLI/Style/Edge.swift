//
//  Edge.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

/// A set of edge positions used to specify padding directions.
///
/// Use `Edge.Set` to specify which edges a padding modifier should apply to.
///
/// ```swift
/// Text("Hello")
///     .padding(.leading, 4)   // indent by 4 spaces
///     .padding(.all, 2)       // 2 spaces on every side
/// ```
public enum Edge: Int, CaseIterable, Sendable {
    case top
    case bottom
    case leading
    case trailing

    /// A set of edges, modeled after SwiftUI's `Edge.Set`.
    public struct Set: OptionSet, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// The top edge.
        public static let top      = Set(rawValue: 1 << 0)
        /// The bottom edge.
        public static let bottom   = Set(rawValue: 1 << 1)
        /// The leading (left) edge.
        public static let leading  = Set(rawValue: 1 << 2)
        /// The trailing (right) edge.
        public static let trailing = Set(rawValue: 1 << 3)
        /// The leading and trailing edges.
        public static let horizontal: Set = [.leading, .trailing]
        /// The top and bottom edges.
        public static let vertical: Set   = [.top, .bottom]
        /// All edges.
        public static let all: Set        = [.top, .bottom, .leading, .trailing]
    }
}
