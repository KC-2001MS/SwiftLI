//
//  VStack.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

/// The horizontal alignment of children within a ``VStack``.
public enum HorizontalAlignment: Sendable {
    /// Align children to the leading (left) edge of the stack.
    case leading
    /// Align children to the trailing (right) edge of the stack.
    case trailing
}

/// A view that arranges its children in a vertical line.
///
/// `VStack` measures each child view, then draws them stacked top-to-bottom
/// into a ``TerminalCanvas``, with an optional gap between children.
///
/// ```swift
/// VStack {
///     Text("Line 1").forgroundColor(.red)
///     Text("Line 2").forgroundColor(.blue)
///     Text("Line 3").bold()
/// }
/// .render()
/// ```
///
/// When children have different widths, use `alignment` to control horizontal
/// positioning:
/// - `.leading` (default): all children are left-aligned.
/// - `.trailing`: all children are right-aligned.
public struct VStack: View, @unchecked Sendable {
    private let children: [any View]
    private let spacing: Int
    private let alignment: HorizontalAlignment
    private let header: String

    /// Creates a VStack with the given children and optional spacing.
    /// - Parameters:
    ///   - alignment: Horizontal alignment when children have different widths. Defaults to `.leading`.
    ///   - spacing: Number of blank rows between each child. Defaults to `0`.
    ///   - content: A ``ViewBuilder`` closure that produces the child views.
    public init(
        alignment: HorizontalAlignment = .leading,
        spacing: Int = 0,
        @ViewBuilder content: () -> Group
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.children = content().contents
        self.header = ""
    }

    /// Creates a VStack directly from an array of views (bypasses ``ViewBuilder``).
    /// Used internally to wrap top-level body arrays in an implicit root VStack.
    init(
        alignment: HorizontalAlignment = .leading,
        spacing: Int = 0,
        children: [any View]
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.children = children
        self.header = ""
    }

    init(
        alignment: HorizontalAlignment,
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
    public func addHeader(_ newHeader: String) -> VStack {
        VStack(alignment: alignment, spacing: spacing, children: children, header: newHeader + header)
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
        var maxWidth = 0
        var totalHeight = 0
        for (i, child) in flat.enumerated() {
            let size = child.measure()
            // Divider spans the full stackWidth, so exclude it from the width calculation.
            if !(child is Divider) && size.width > maxWidth {
                maxWidth = size.width
            }
            totalHeight += size.height
            if i < flat.count - 1 {
                totalHeight += spacing
            }
        }
        return Size(width: maxWidth, height: totalHeight)
    }

    @_spi(RenderingInternals)
    public func draw(into canvas: TerminalCanvas, at origin: Point) {
        _drawInto(canvas: canvas, at: origin)
    }

    /// Recursively flattens ``Group`` children so that a Group inside a VStack
    /// is transparent — its children are treated as direct VStack children,
    /// inheriting any styling the Group carries via ``addHeader``.
    /// If this VStack itself has an accumulated `header` style, it is applied
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

    /// Flattens without re-applying the VStack header (used for Group children
    /// that already had the header applied via addHeader above).
    private func _flattenChildrenNoHeader(_ views: [any View]) -> [any View] {
        views.flatMap { view -> [any View] in
            if let group = view as? Group {
                return _flattenChildrenNoHeader(group._resolvedChildren)
            }
            return [view]
        }
    }

    private func _drawInto(canvas: TerminalCanvas, at origin: Point) {
        let flat = _flattenChildren(children)
        // Compute overall stack width for alignment and Divider span.
        // Divider returns 0 so it doesn't artificially constrain the width.
        let stackWidth = flat.map { child -> Int in
            if child is Divider { return 0 }
            return child.measure().width
        }.max() ?? 0

        var y = origin.row
        for (i, child) in flat.enumerated() {
            let size = child.measure()
            if let divider = child as? Divider {
                // Horizontal divider spans the full stack width.
                divider.drawHorizontal(into: canvas, at: Point(column: origin.column, row: y), width: stackWidth)
            } else {
                let colOffset: Int
                switch alignment {
                case .leading:
                    colOffset = 0
                case .trailing:
                    colOffset = stackWidth - size.width
                }
                let childOrigin = Point(column: origin.column + colOffset, row: y)
                canvas.expand(toFit: Rect(origin: childOrigin, size: size))
                child.draw(into: canvas, at: childOrigin)
            }
            y += size.height
            if i < flat.count - 1 {
                y += spacing
            }
        }
    }
}
