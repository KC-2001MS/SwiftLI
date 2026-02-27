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
    let header: String
    
    let contents: [View]
    
    /// Creates a group of views.
    /// - Parameter contents: A ViewBuilder that produces the views to group.
    public init(@ViewBuilder contents: () -> [View]) {
        self.header = ""
        self.contents = contents()
    }
    
    init(contents: [View]) {
        self.header = ""
        self.contents = contents
    }
    
    init(header: String, contents: [View]) {
        self.header = header
        self.contents = contents
    }
    /// What the view displays
    public var body: [View] {
        var result: [any View] = []
        for child in contents {
            result.append(child.addHeader(header))
        }
        return result
    }
    
    public func addHeader(_ header: String) -> Self {
        return Group(header: header + self.header, contents: self.contents)
    }

    public func render() {
        let canvas = TerminalCanvas(width: 0, height: 0)
        _drawChildren(into: canvas, at: .zero)
        canvas.flush()
    }

    public func renderString() -> String {
        let canvas = TerminalCanvas(width: 0, height: 0)
        _drawChildren(into: canvas, at: .zero)
        return canvas.toString()
    }

    public func measure() -> Size {
        let children = body
        var maxWidth = 0
        var totalHeight = 0
        for child in children {
            let size = child.measure()
            if size.width > maxWidth { maxWidth = size.width }
            totalHeight += size.height
        }
        return Size(width: maxWidth, height: totalHeight)
    }

    public func draw(into canvas: TerminalCanvas, at origin: Point) {
        _drawChildren(into: canvas, at: origin)
    }

    /// Draws children vertically stacked into the canvas.
    private func _drawChildren(into canvas: TerminalCanvas, at origin: Point) {
        var y = origin.row
        for child in body {
            let size = child.measure()
            canvas.expand(toFit: Rect(origin: Point(column: origin.column, row: y), size: size))
            child.draw(into: canvas, at: Point(column: origin.column, row: y))
            y += size.height
        }
    }
}
