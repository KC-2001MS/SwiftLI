//
//  Spacer.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/27.
//


/// A flexible space
///
/// This is the most basic view that displays text in the terminal.
///
/// View to add space horizontally
/// ```swift
/// let spacer = Spacer(10)
/// spacer.render()
/// ```
/// Modifiers can be added to change the style.
public struct Spacer: View {
    private let header: String
    
    private let count: Int
    
    private let footer: Bool
    /// Creates a space view that is displayed in the terminal.
    /// - Parameter count: Space Width
    public init(_ count: Int) {
        self.header = ""
        self.count = count
        self.footer = false
    }
    /// Creates a space view that is displayed in the terminal.
    public init() {
        self.header = ""
        self.count = 1
        self.footer = false
    }
    
    private init(
        header: String,
        count: Int,
        footer: Bool = false
    ) {
        self.header = header
        self.count = count
        self.footer = footer
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
    /// Whether to break the View at the end
    /// - Parameter newLine: whether or not to start a new line
    /// - Returns: Adapted view
    public func newLine(_ newLine: Bool = true) -> Spacer {
        return .init(header: header, count: count, footer: newLine)
    }
}
