//
//  Break.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/27.
//


public struct Break: View {
    private let count: Int
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
}
