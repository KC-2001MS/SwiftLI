//
//  VSpacer.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/31.
//


/// A flexible space
public struct VSpacer: View {
    private let count: Int
    
    private var header: String
    /// Creates a space view that is displayed in the terminal.
    /// - Parameter count: Space Width
    public init(_ count: Int) {
        self.count = count
        self.header = ""
    }
    /// Creates a space view that is displayed in the terminal.
    public init() {
        self.count = 1
        self.header = ""
    }
    
    private init(header: String,_ count: Int) {
        self.count = count
        self.header = header
    }
    /// What the view displays
    public var body: [View] {
        Break(count + 1)
    }
}
