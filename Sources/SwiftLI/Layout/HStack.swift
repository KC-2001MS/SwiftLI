//
//  HStack.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

/// The vertical alignment of children within an ``HStack``.
public enum VerticalAlignment: Sendable {
    /// Align children to the top row of the stack.
    case top
    /// Align children to the bottom row of the stack.
    case bottom
}

/// A view that arranges its children in a horizontal line.
///
/// `HStack` measures each child view, then draws them side-by-side into a
/// ``TerminalCanvas``, with an optional gap between children.
///
/// ```swift
/// HStack {
///     Text("Left").forgroundColor(.red)
///     Text("  |  ")
///     Text("Right").forgroundColor(.blue)
/// }
/// .render()
/// ```
///
/// When children have different heights, use `alignment` to control vertical
/// positioning:
/// - `.top` (default): all children start at the same row.
/// - `.bottom`: all children end at the same row.
public struct HStack: View, @unchecked Sendable {
    private let children: [any View]
    private let spacing: Int
    private let alignment: VerticalAlignment
    private let header: String

    /// Creates an HStack with the given children and optional spacing.
    /// - Parameters:
    ///   - alignment: Vertical alignment when children have different heights. Defaults to `.top`.
    ///   - spacing: Number of space columns between each child. Defaults to `0`.
    ///   - content: A ``ViewBuilder`` closure that produces the child views.
    public init(
        alignment: VerticalAlignment = .top,
        spacing: Int = 0,
        @ViewBuilder content: () -> Group
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.children = content().contents
        self.header = ""
    }

    init(
        alignment: VerticalAlignment,
        spacing: Int,
        children: [any View],
        header: String
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.children = children
        self.header = header
    }

    public var body: some View { Group(contents: []) }

    @_spi(RenderingInternals)
    public func addHeader(_ newHeader: String) -> HStack {
        HStack(alignment: alignment, spacing: spacing, children: children, header: newHeader + header)
    }

    public func render() {
        let canvas = TerminalCanvas(width: 0, height: 0)
        _drawInto(canvas: canvas, at: .zero)
        canvas.flush()
    }

    @_spi(RenderingInternals)
    public func renderString() -> String {
        let canvas = TerminalCanvas(width: 0, height: 0)
        _drawInto(canvas: canvas, at: .zero)
        return canvas.toString()
    }

    @_spi(RenderingInternals)
    public func measure() -> Size {
        let flat = _flattenChildren(children)
        var totalWidth = 0
        var maxHeight = 0
        for (i, child) in flat.enumerated() {
            let size = _childSize(child)
            totalWidth += size.width
            if i < flat.count - 1 {
                totalWidth += spacing
            }
            if size.height > maxHeight {
                maxHeight = size.height
            }
        }
        return Size(width: totalWidth, height: maxHeight)
    }

    @_spi(RenderingInternals)
    public func draw(into canvas: TerminalCanvas, at origin: Point) {
        _drawInto(canvas: canvas, at: origin)
    }

    /// Recursively flattens ``Group`` children so that a Group inside an HStack
    /// is transparent — its children are treated as direct HStack children,
    /// inheriting any styling the Group carries via ``addHeader``.
    /// If this HStack itself has an accumulated `header` style, it is applied
    /// to every child before flattening.
    private func _flattenChildren(_ views: [any View]) -> [any View] {
        let styled: [any View] = header.isEmpty ? views : views.map { $0.addHeader(header) }
        return styled.flatMap { view -> [any View] in
            if let group = view as? Group {
                return _flattenChildrenNoHeader(group._resolvedChildren)
            }
            return [view]
        }
    }

    private func _flattenChildrenNoHeader(_ views: [any View]) -> [any View] {
        views.flatMap { view -> [any View] in
            if let group = view as? Group {
                return _flattenChildrenNoHeader(group._resolvedChildren)
            }
            return [view]
        }
    }

    /// Returns the effective size of a child, treating ``Spacer`` as horizontal
    /// and ``Divider`` as a 1-column-wide placeholder (height resolved later).
    private func _childSize(_ child: any View) -> Size {
        if let spacer = child as? Spacer {
            return spacer.horizontalMeasure()
        }
        if child is Divider {
            // Width = 1; height is a placeholder — resolved to stackHeight in _drawInto.
            return Size(width: 1, height: 1)
        }
        return child.measure()
    }

    private func _drawInto(canvas: TerminalCanvas, at origin: Point) {
        let flat = _flattenChildren(children)
        // Compute overall stack height.
        // Divider and Spacer take the height of the tallest non-Divider/Spacer child.
        let stackHeight = flat.map { child -> Int in
            if child is Divider { return 0 }
            if let spacer = child as? Spacer { return spacer.horizontalMeasure().height }
            return child.measure().height
        }.max() ?? 0

        var x = origin.column
        for (i, child) in flat.enumerated() {
            let size = _childSize(child)
            let rowOffset: Int
            switch alignment {
            case .top:
                rowOffset = 0
            case .bottom:
                rowOffset = stackHeight - size.height
            }
            let childOrigin = Point(column: x, row: origin.row + rowOffset)
            if let spacer = child as? Spacer {
                spacer.drawHorizontal(into: canvas, at: childOrigin)
            } else if let divider = child as? Divider {
                divider.drawVertical(into: canvas, at: Point(column: x, row: origin.row), height: stackHeight)
            } else {
                canvas.expand(toFit: Rect(origin: childOrigin, size: size))
                child.draw(into: canvas, at: childOrigin)
            }
            x += size.width
            if i < flat.count - 1 {
                x += spacing
            }
        }
    }
}
