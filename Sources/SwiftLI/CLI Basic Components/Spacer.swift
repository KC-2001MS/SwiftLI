//
//  Spacer.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/27.
//


/// A flexible space
public struct Spacer: View {
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
    /// Modifier to adapt background color to existing text
    /// - Parameter color: Color to be specified as background color
    /// - Returns: Spacer view with background color adaptation
    public func background(_ color: Color) -> Spacer {
        return .init(header: "\(header)\u{001B}[4\(color.ansi)m", count: count)
    }
}
