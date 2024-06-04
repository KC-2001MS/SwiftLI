//
//  Spacer.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/27.
//


/// A flexible space
public struct HSpacer: View {
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
    
    private init(header: String,count: Int) {
        self.count = count
        self.header = header
    }
    /// What the view displays
    public var body: [View] {
        Text(repeating: " ", count: count)
    }
    /// Modifier to adapt foreground color to existing text
    /// - Parameter color: Color to be specified as foreground color
    /// - Returns: HSpacerview with foreground color adaptation
    public func forgroundColor(_ color: Color) -> HSpacer {
        return .init(header: "\(header)\u{001B}[3\(color.name)m", count: count)
    }
    
    public func background(_ color: Color) -> HSpacer {
        return .init(header: "\(header)\u{001B}[4\(color.name)m", count: count)
    }
}
