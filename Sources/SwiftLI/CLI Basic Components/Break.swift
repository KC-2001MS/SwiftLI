//
//  Break.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/27.
//


/// View to start a new line
/// 
/// A line break can be added.
/// ```swift
/// let break = Break()
/// break.render()
/// ```
public struct Break: View, Sendable, Equatable {
    let count: Int
    /// Creates a break view that is displayed in the terminal.
    /// - Parameter count: Space Width
    public init(_ count: Int) {
        self.count = count
    }
    /// Creates a space view that is displayed in the terminal.
    public init() {
        self.count = 1
    }
    /// What the view displays
    public var body: [View] {
        Text(repeating: "\n", count: count)
    }
    
    public func addHeader(_ header: String) -> Self {
        return Break(count)
    }
}
