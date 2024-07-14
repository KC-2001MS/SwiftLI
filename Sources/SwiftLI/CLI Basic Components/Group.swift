//
//  Group.swift
//  
//  
//  Created by Keisuke Chinone on 2024/05/27.
//


/// View for grouping multiple views together
///
/// Group views make it easy to build complex views. Here is an example of its use
/// ```swift
/// let group = Group {
///     Text("Group View")
///         .background(Color.white)
///         .forgroundColor(Color.blue)
///         .bold()
///
///     Break(1)
///
///     Group {
///         Text("Group(@ViewBuilder contents: () -> [View])")
///            .forgroundColor(Color.cyan)
///
///        Group {
///             Text("Group")
///        }
///     }
///     .newLine()
/// }
/// 
/// group.render()
/// ```
public struct Group: View {
    let contents: [View]
    
    let footer: Bool
    /// Creates a group of views.
    /// - Parameter contents: A ViewBuilder that produces the views to group.
    public init(@ViewBuilder contents: () -> [View]) {
        self.contents = contents()
        self.footer = false
    }
    
    init(contents: [View], footer: Bool) {
        self.contents = contents
        self.footer = footer
    }
    /// What the view displays
    public var body: [View] {
        var display: [View] = contents
        if footer {
            display.append(Break())
        }
        return display
    }
    /// Whether to break the View at the end
    /// - Parameter newLine: whether or not to start a new line
    /// - Returns: Adapted view
    public func newLine(_ newLine: Bool = true) -> Group {
        return .init(contents: contents, footer: newLine)
    }
}
