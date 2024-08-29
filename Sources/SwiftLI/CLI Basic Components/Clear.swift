//
//  Clear.swift
//  SwiftLI
//  
//  Created by Keisuke Chinone on 8/29/24.
//

// View to delete view
///
/// Deletes a view
/// ```swift
/// let clear = Clear()
/// clear.render()
/// ```
public struct Clear: View, Sendable, Equatable {
    /// Create a view that removes the terminal display.
    public init() {}
    
    /// What the view displays
    public var body: [View] {
        Text(header: "\u{001B}[2J", content: "", footer: false)
    }
    
    public func addHeader(_ header: String) -> Self {
        return Clear()
    }
}
