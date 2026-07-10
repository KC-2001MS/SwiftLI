//
//  NodeLayout.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/06.
//

/// The layout engine that turns a ``RenderNode`` tree into concrete terminal
/// output: sizes, canvas drawings, and finally a ``Frame``.
///
/// `NodeLayout` is a pure, stateless engine. Because it operates on the
/// intermediate representation rather than on views, arbitrary nesting such
/// as `HStack > VStack > HStack` resolves naturally through recursion: each
/// stack measures its children in its own axis and assigns them absolute
/// canvas positions.
public enum NodeLayout {

    /// The direction in which a parent container arranges its children.
    ///
    /// Direction-adaptive nodes (`.spacer`, `.divider`) use the axis to decide
    /// whether they occupy columns (inside an ``HStack``) or rows (everywhere
    /// else).
    public enum Axis: Sendable {
        case horizontal
        case vertical
    }

    // MARK: - Frame

    /// Lays out a node tree from the origin and captures the result as a ``Frame``.
    public static func frame(of node: RenderNode) -> Frame {
        let canvas = TerminalCanvas(width: 0, height: 0)
        draw(node, into: canvas, at: .zero, axis: .vertical)
        return Frame(preamble: collectRaw(node), lines: canvas.lines())
    }

    // MARK: - Measuring

    /// Measures the size a node occupies when laid out along `axis`.
    ///
    /// - Parameters:
    ///   - proposedWidth: The width a parent offers this node, used so text
    ///     wraps to the available columns. `nil` means unconstrained (the
    ///     natural, content-driven width — the historical behaviour).
    ///   - lineLimit: The maximum number of visual lines a ``text`` may render.
    public static func measure(_ node: RenderNode, axis: Axis = .vertical, proposedWidth: Int? = nil, lineLimit: Int? = nil) -> Size {
        switch node {
        case .empty, .raw:
            return .zero
        case .text(let header, let contents):
            let s = styledText(header: header, contents: contents, proposedWidth: proposedWidth, lineLimit: lineLimit)
            return TextMetrics.size(of: s.isEmpty ? " " : s)
        case .spacer(_, let count):
            return axis == .horizontal ? Size(width: count, height: 1) : Size(width: 0, height: count)
        case .divider(_, _, _, let count, let fillsWidth):
            // Placeholder size — the enclosing stack stretches the divider to
            // its full height (HStack) or width (VStack) during layout. A
            // width-filling divider reports the proposed (or terminal) width.
            if axis == .horizontal { return Size(width: 1, height: 1) }
            return Size(width: fillsWidth ? (proposedWidth ?? TerminalSize.current.columns) : count, height: 1)
        case .group(let children):
            return measureColumn(flatten(children), spacing: 0, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .vstack(_, let spacing, let children):
            return measureColumn(flatten(children), spacing: spacing, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .hstack(_, let spacing, let children):
            // Horizontal width division isn't modelled, so children keep their
            // natural width (no wrapping) inside an HStack.
            return measureRow(flatten(children), spacing: spacing, lineLimit: lineLimit)
        case .padding(let edges, let length, let child):
            let inner = proposedWidth.map { $0 - horizontalPadding(edges, length) }
            var size = measure(child, axis: axis, proposedWidth: inner, lineLimit: lineLimit)
            if edges.contains(.leading)  { size.width  += length }
            if edges.contains(.trailing) { size.width  += length }
            if edges.contains(.top)      { size.height += length }
            if edges.contains(.bottom)   { size.height += length }
            return size
        case .frame(let width, let height, let fillWidth, let fillHeight, _, let child):
            let r = resolveFrame(width: width, height: height, fillWidth: fillWidth, fillHeight: fillHeight, child: child, proposedWidth: proposedWidth, lineLimit: lineLimit)
            return Size(width: r.width, height: r.height)
        case .lineLimit(let limit, let child):
            return measure(child, axis: axis, proposedWidth: proposedWidth, lineLimit: limit)
        case .scroll(_, let height, let thumb, _, let child):
            let childSize = measure(child, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit)
            let barWidth = (thumb != nil && childSize.height > height) ? 2 : 0
            return Size(width: childSize.width + barWidth, height: height)
        case .hscroll(_, let extent, let thumb, _, let child):
            let childSize = measure(child, axis: .vertical, proposedWidth: nil, lineLimit: lineLimit)
            let barRow = (thumb != nil && childSize.width > extent) ? 1 : 0
            return Size(width: extent, height: childSize.height + barRow)
        case .border(_, _, _, let child):
            // The box adds one column on each side and one row top and bottom.
            let inner = proposedWidth.map { Swift.max(0, $0 - 2) }
            let childSize = measure(child, axis: .vertical, proposedWidth: inner, lineLimit: lineLimit)
            return Size(width: childSize.width + 2, height: childSize.height + 2)
        case .shadow(_, let child):
            // The drop shadow adds one column and one row to the footprint.
            let inner = proposedWidth.map { Swift.max(0, $0 - 1) }
            let childSize = measure(child, axis: .vertical, proposedWidth: inner, lineLimit: lineLimit)
            return Size(width: childSize.width + 1, height: childSize.height + 1)
        case .viewThatFits(let cw, let ch, let candidates):
            let chosen = fittingCandidate(candidates, checkWidth: cw, checkHeight: ch, proposedWidth: proposedWidth, lineLimit: lineLimit)
            return measure(chosen, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)
        }
    }

    /// Total horizontal padding contributed by the given edges.
    private static func horizontalPadding(_ edges: Edge.Set, _ length: Int) -> Int {
        (edges.contains(.leading) ? length : 0) + (edges.contains(.trailing) ? length : 0)
    }

    // MARK: - Drawing

    /// Draws a node into `canvas` with its top-left corner at `origin`.
    ///
    /// `proposedWidth` and `lineLimit` flow down exactly as in ``measure(_:axis:proposedWidth:lineLimit:)``.
    public static func draw(_ node: RenderNode, into canvas: TerminalCanvas, at origin: Point, axis: Axis = .vertical, proposedWidth: Int? = nil, lineLimit: Int? = nil) {
        switch node {
        case .empty, .raw:
            return
        case .text(let header, let contents):
            let s = styledText(header: header, contents: contents, proposedWidth: proposedWidth, lineLimit: lineLimit)
            if s.isEmpty { return }
            canvas.expand(toFit: Rect(origin: origin, size: TextMetrics.size(of: s)))
            // `hidden()` replaces the glyphs with spaces while preserving the
            // exact column width, so the layout never shifts — only the
            // visible characters disappear.
            canvas.write(isHidden(header) ? blankedGlyphs(of: s) : s, at: origin)
        case .spacer(let header, let count):
            if axis == .horizontal {
                canvas.expand(toFit: Rect(origin: origin, size: Size(width: count, height: 1)))
                canvas.write(header + String(repeating: " ", count: count), at: origin)
            } else {
                // Vertical spacer: occupies blank rows only.
                canvas.expand(toFit: Rect(origin: origin, size: Size(width: 0, height: count)))
            }
        case .divider(let header, let character, let verticalCharacter, let count, let fillsWidth):
            // A divider outside of a stack falls back to its own count/height,
            // or the proposed/terminal width when it is width-filling.
            if axis == .horizontal {
                drawVerticalDivider(header: header, character: verticalCharacter, height: 1, into: canvas, at: origin)
            } else {
                let width = fillsWidth ? (proposedWidth ?? TerminalSize.current.columns) : count
                drawHorizontalDivider(header: header, character: character, width: width, into: canvas, at: origin)
            }
        case .group(let children):
            drawColumn(flatten(children), alignment: .leading, spacing: 0, into: canvas, at: origin, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .vstack(let alignment, let spacing, let children):
            drawColumn(flatten(children), alignment: alignment, spacing: spacing, into: canvas, at: origin, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .hstack(let alignment, let spacing, let children):
            drawRow(flatten(children), alignment: alignment, spacing: spacing, into: canvas, at: origin, lineLimit: lineLimit)
        case .padding(let edges, let length, let child):
            canvas.expand(toFit: Rect(origin: origin, size: measure(node, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)))
            let childOrigin = Point(
                column: origin.column + (edges.contains(.leading) ? length : 0),
                row: origin.row + (edges.contains(.top) ? length : 0)
            )
            let inner = proposedWidth.map { $0 - horizontalPadding(edges, length) }
            draw(child, into: canvas, at: childOrigin, axis: axis, proposedWidth: inner, lineLimit: lineLimit)
        case .frame(let width, let height, let fillWidth, let fillHeight, let alignment, let child):
            drawFrame(width: width, height: height, fillWidth: fillWidth, fillHeight: fillHeight, alignment: alignment, child: child, into: canvas, at: origin, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .lineLimit(let limit, let child):
            draw(child, into: canvas, at: origin, axis: axis, proposedWidth: proposedWidth, lineLimit: limit)
        case .scroll(let offset, let height, let thumb, let track, let child):
            drawScroll(offset: offset, height: height, thumb: thumb, track: track, child: child, into: canvas, at: origin, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .hscroll(let offset, let extent, let thumb, let track, let child):
            drawHScroll(offset: offset, extent: extent, thumb: thumb, track: track, child: child, into: canvas, at: origin, lineLimit: lineLimit)
        case .border(let header, let fill, let style, let child):
            drawBorder(header: header, fill: fill, style: style, child: child, into: canvas, at: origin, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .shadow(let header, let child):
            drawShadow(header: header, child: child, into: canvas, at: origin, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .viewThatFits(let cw, let ch, let candidates):
            let chosen = fittingCandidate(candidates, checkWidth: cw, checkHeight: ch, proposedWidth: proposedWidth, lineLimit: lineLimit)
            draw(chosen, into: canvas, at: origin, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)
        }
    }

    /// Chooses the first candidate whose natural size fits the available space,
    /// falling back to the last candidate when none fit.
    static func fittingCandidate(_ candidates: [RenderNode], checkWidth: Bool, checkHeight: Bool, proposedWidth: Int?, lineLimit: Int?) -> RenderNode {
        guard let last = candidates.last else { return .empty }
        let availWidth  = proposedWidth ?? TerminalSize.current.columns
        let availHeight = TerminalSize.current.rows
        for candidate in candidates {
            // Measure at the natural (unconstrained) size, then test it against
            // what is available — a candidate that would have to wrap or clip is
            // considered not to fit.
            let size = measure(candidate, axis: .vertical, proposedWidth: nil, lineLimit: lineLimit)
            let widthFits  = !checkWidth  || size.width  <= availWidth
            let heightFits = !checkHeight || size.height <= availHeight
            if widthFits && heightFits { return candidate }
        }
        return last
    }

    // MARK: - Scroll layout

    private static func drawScroll(offset: Int, height: Int, thumb: String?, track: String?, child: RenderNode, into canvas: TerminalCanvas, at origin: Point, proposedWidth: Int?, lineLimit: Int?) {
        guard height > 0 else { return }

        // Lay the child out in full, then take a `height`-row vertical window.
        let childCanvas = TerminalCanvas(width: 0, height: 0)
        draw(child, into: childCanvas, at: .zero, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit)
        let lines = childCanvas.lines()
        let contentHeight = lines.count
        let maxOffset = Swift.max(0, contentHeight - height)
        let clamped = Swift.min(Swift.max(offset, 0), maxOffset)

        let contentWidth = lines.map { TextMetrics.visibleWidth(TextMetrics.stripANSI($0)) }.max() ?? 0
        let scrollable = contentHeight > height
        let showBar = thumb != nil && scrollable
        let barColumn = contentWidth + 1   // one blank gap before the scrollbar

        // Scrollbar thumb geometry (proportional to how much is visible).
        var thumbStart = 0
        var thumbSize = height
        if showBar {
            thumbSize = Swift.max(1, height * height / contentHeight)
            let travel = height - thumbSize
            thumbStart = maxOffset > 0 ? clamped * travel / maxOffset : 0
        }

        canvas.expand(toFit: Rect(origin: origin, size: Size(width: contentWidth + (showBar ? 2 : 0), height: height)))
        for row in 0..<height {
            let contentRow = clamped + row
            if contentRow < contentHeight {
                let line = lines[contentRow]
                if !line.isEmpty { canvas.write(line, at: Point(column: origin.column, row: origin.row + row)) }
            }
            if showBar, let thumb, let track {
                let glyph = (row >= thumbStart && row < thumbStart + thumbSize) ? thumb : track
                canvas.write(glyph, at: Point(column: origin.column + barColumn, row: origin.row + row))
            }
        }
    }

    private static func drawHScroll(offset: Int, extent: Int, thumb: String?, track: String?, child: RenderNode, into canvas: TerminalCanvas, at origin: Point, lineLimit: Int?) {
        guard extent > 0 else { return }

        // Lay the child out at its natural width, then take an `extent`-column
        // horizontal window of every row.
        let childCanvas = TerminalCanvas(width: 0, height: 0)
        draw(child, into: childCanvas, at: .zero, axis: .vertical, proposedWidth: nil, lineLimit: lineLimit)
        let lines = childCanvas.lines()
        let contentHeight = lines.count
        let contentWidth = lines.map { TextMetrics.visibleWidth(TextMetrics.stripANSI($0)) }.max() ?? 0
        let maxOffset = Swift.max(0, contentWidth - extent)
        let clamped = Swift.min(Swift.max(offset, 0), maxOffset)

        let scrollable = contentWidth > extent
        let showBar = thumb != nil && scrollable
        let barRow = contentHeight   // one row below the content

        // Scrollbar thumb geometry (proportional to how much is visible).
        var thumbStart = 0
        var thumbSize = extent
        if showBar {
            thumbSize = Swift.max(1, extent * extent / contentWidth)
            let travel = extent - thumbSize
            thumbStart = maxOffset > 0 ? clamped * travel / maxOffset : 0
        }

        canvas.expand(toFit: Rect(origin: origin, size: Size(width: extent, height: contentHeight + (showBar ? 1 : 0))))
        for row in 0..<contentHeight {
            let windowed = TextMetrics.sliceColumns(lines[row], from: clamped, width: extent)
            if !windowed.isEmpty { canvas.write(windowed, at: Point(column: origin.column, row: origin.row + row)) }
        }
        if showBar, let thumb, let track {
            for col in 0..<extent {
                let glyph = (col >= thumbStart && col < thumbStart + thumbSize) ? thumb : track
                canvas.write(glyph, at: Point(column: origin.column + col, row: origin.row + barRow))
            }
        }
    }

    // MARK: - Border & shadow layout

    /// Draws a box of box-drawing glyphs around `child`, placing the child one
    /// cell in from the top-left corner.
    private static func drawBorder(header: String, fill: String, style: BorderStyle, child: RenderNode, into canvas: TerminalCanvas, at origin: Point, proposedWidth: Int?, lineLimit: Int?) {
        let g = style.glyphs
        let inner = proposedWidth.map { Swift.max(0, $0 - 2) }
        let childSize = measure(child, axis: .vertical, proposedWidth: inner, lineLimit: lineLimit)
        let w = childSize.width
        let h = childSize.height
        let reset = "\u{001B}[0m"

        canvas.expand(toFit: Rect(origin: origin, size: Size(width: w + 2, height: h + 2)))

        // With a fill, every border cell — corners included — takes the fill
        // background, so the box reads as one solid rectangle. This matches how
        // Textual, Rich and Lipgloss render a filled box: the rounded glyphs are
        // drawn *on* the fill as decoration, and the silhouette stays square. A
        // single cell has only one background, so a rounded *filled* corner is
        // not representable; a truly round silhouette needs an unfilled outline.
        let edge = header + fill

        let top = edge + String(g.topLeft) + String(repeating: g.horizontal, count: w) + String(g.topRight) + reset
        canvas.write(top, at: origin)

        let bottom = edge + String(g.bottomLeft) + String(repeating: g.horizontal, count: w) + String(g.bottomRight) + reset
        canvas.write(bottom, at: Point(column: origin.column, row: origin.row + h + 1))

        let side = edge + String(g.vertical) + reset
        for r in 0..<h {
            canvas.write(side, at: Point(column: origin.column, row: origin.row + 1 + r))
            canvas.write(side, at: Point(column: origin.column + w + 1, row: origin.row + 1 + r))
        }

        // Paint the interior when a fill is requested, so the whole inside of
        // the box is coloured — not just the cells the child writes.
        if !fill.isEmpty && w > 0 && h > 0 {
            let fillRow = fill + String(repeating: " ", count: w) + reset
            for r in 0..<h {
                canvas.write(fillRow, at: Point(column: origin.column + 1, row: origin.row + 1 + r))
            }
        }

        // The child sits inside the box, inset by one cell. When filled, the
        // child inherits the fill so its text sits on the fill background too.
        let content = fill.isEmpty ? child : child.applyingHeader(fill)
        draw(content, into: canvas, at: Point(column: origin.column + 1, row: origin.row + 1), axis: .vertical, proposedWidth: inner, lineLimit: lineLimit)
    }

    /// Draws a one-cell drop shadow along `child`'s right and bottom edges,
    /// offset a single cell down and to the right, then draws the child on top.
    private static func drawShadow(header: String, child: RenderNode, into canvas: TerminalCanvas, at origin: Point, proposedWidth: Int?, lineLimit: Int?) {
        let inner = proposedWidth.map { Swift.max(0, $0 - 1) }
        let childSize = measure(child, axis: .vertical, proposedWidth: inner, lineLimit: lineLimit)
        let w = childSize.width
        let h = childSize.height

        guard w > 0, h > 0 else {
            draw(child, into: canvas, at: origin, axis: .vertical, proposedWidth: inner, lineLimit: lineLimit)
            return
        }

        canvas.expand(toFit: Rect(origin: origin, size: Size(width: w + 1, height: h + 1)))

        // A single shadow cell: a styled space so trailing shadow is not trimmed.
        let cell = header + " " + "\u{001B}[0m"
        // Bottom band, one row below the child.
        for c in 1...w {
            canvas.write(cell, at: Point(column: origin.column + c, row: origin.row + h))
        }
        // Right band, one column right of the child (shares the corner cell).
        for r in 1...h {
            canvas.write(cell, at: Point(column: origin.column + w, row: origin.row + r))
        }

        // The content draws on top, covering the band it overlaps.
        draw(child, into: canvas, at: origin, axis: .vertical, proposedWidth: inner, lineLimit: lineLimit)
    }

    // MARK: - Stack layout

    /// Flattens transparent `.group` nodes so their children become direct
    /// children of the enclosing stack. `.empty` nodes are dropped.
    static func flatten(_ children: [RenderNode]) -> [RenderNode] {
        children.flatMap { node -> [RenderNode] in
            switch node {
            case .group(let inner): return flatten(inner)
            case .empty: return []
            default: return [node]
            }
        }
    }

    private static func measureColumn(_ children: [RenderNode], spacing: Int, proposedWidth: Int? = nil, lineLimit: Int? = nil) -> Size {
        var maxWidth = 0
        var totalHeight = 0
        for (i, child) in children.enumerated() {
            let size = measure(child, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit)
            // Dividers span the full stack width, so they don't constrain it.
            if !isDivider(child) && size.width > maxWidth { maxWidth = size.width }
            totalHeight += size.height
            if i < children.count - 1 { totalHeight += spacing }
        }
        return Size(width: maxWidth, height: totalHeight)
    }

    private static func measureRow(_ children: [RenderNode], spacing: Int, lineLimit: Int? = nil) -> Size {
        var totalWidth = 0
        var maxHeight = 0
        for (i, child) in children.enumerated() {
            let size = measure(child, axis: .horizontal, lineLimit: lineLimit)
            totalWidth += size.width
            if i < children.count - 1 { totalWidth += spacing }
            if size.height > maxHeight { maxHeight = size.height }
        }
        return Size(width: totalWidth, height: maxHeight)
    }

    private static func drawColumn(
        _ children: [RenderNode],
        alignment: HorizontalAlignment,
        spacing: Int,
        into canvas: TerminalCanvas,
        at origin: Point,
        proposedWidth: Int? = nil,
        lineLimit: Int? = nil
    ) {
        // Dividers span the stack, so they don't participate in the width.
        let stackWidth = children.map { child -> Int in
            isDivider(child) ? 0 : measure(child, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit).width
        }.max() ?? 0

        var y = origin.row
        for (i, child) in children.enumerated() {
            let size = measure(child, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit)
            if case .divider(let header, let character, _, let count, let fillsWidth) = child {
                let width = fillsWidth ? (proposedWidth ?? TerminalSize.current.columns) : (stackWidth > 0 ? stackWidth : count)
                drawHorizontalDivider(header: header, character: character, width: width, into: canvas, at: Point(column: origin.column, row: y))
            } else {
                let colOffset: Int
                switch alignment {
                case .leading:  colOffset = 0
                case .trailing: colOffset = stackWidth - size.width
                }
                let childOrigin = Point(column: origin.column + colOffset, row: y)
                canvas.expand(toFit: Rect(origin: childOrigin, size: size))
                draw(child, into: canvas, at: childOrigin, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit)
            }
            y += size.height
            if i < children.count - 1 { y += spacing }
        }
    }

    private static func drawRow(
        _ children: [RenderNode],
        alignment: VerticalAlignment,
        spacing: Int,
        into canvas: TerminalCanvas,
        at origin: Point,
        lineLimit: Int? = nil
    ) {
        // Dividers stretch to the stack height, so they don't participate in it.
        let stackHeight = children.map { child -> Int in
            isDivider(child) ? 0 : measure(child, axis: .horizontal, lineLimit: lineLimit).height
        }.max() ?? 0

        var x = origin.column
        for (i, child) in children.enumerated() {
            let size = measure(child, axis: .horizontal, lineLimit: lineLimit)
            if case .divider(let header, _, let verticalCharacter, _, _) = child {
                drawVerticalDivider(header: header, character: verticalCharacter, height: Swift.max(stackHeight, 1), into: canvas, at: Point(column: x, row: origin.row))
            } else {
                let rowOffset: Int
                switch alignment {
                case .top:    rowOffset = 0
                case .bottom: rowOffset = stackHeight - size.height
                }
                let childOrigin = Point(column: x, row: origin.row + rowOffset)
                canvas.expand(toFit: Rect(origin: childOrigin, size: size))
                draw(child, into: canvas, at: childOrigin, axis: .horizontal, lineLimit: lineLimit)
            }
            x += size.width
            if i < children.count - 1 { x += spacing }
        }
    }

    // MARK: - Frame layout

    /// Resolves a frame's concrete size and the width it proposes to its child.
    static func resolveFrame(width: Int?, height: Int?, fillWidth: Bool, fillHeight: Bool, child: RenderNode, proposedWidth: Int?, lineLimit: Int?) -> (width: Int, height: Int, childProposedWidth: Int?) {
        let outerWidth: Int?
        if let width { outerWidth = Swift.max(0, width) }
        else if fillWidth { outerWidth = proposedWidth ?? TerminalSize.current.columns }
        else { outerWidth = nil }

        // Propose our resolved width to the child so its text wraps to it.
        let childSize = measure(child, axis: .vertical, proposedWidth: outerWidth, lineLimit: lineLimit)
        let finalWidth = outerWidth ?? childSize.width

        let outerHeight: Int?
        if let height { outerHeight = Swift.max(0, height) }
        else if fillHeight { outerHeight = TerminalSize.current.rows }
        else { outerHeight = nil }
        let finalHeight = outerHeight ?? childSize.height

        return (finalWidth, finalHeight, outerWidth)
    }

    private static func drawFrame(width: Int?, height: Int?, fillWidth: Bool, fillHeight: Bool, alignment: Alignment, child: RenderNode, into canvas: TerminalCanvas, at origin: Point, proposedWidth: Int?, lineLimit: Int?) {
        let r = resolveFrame(width: width, height: height, fillWidth: fillWidth, fillHeight: fillHeight, child: child, proposedWidth: proposedWidth, lineLimit: lineLimit)
        guard r.width > 0, r.height > 0 else { return }

        // Render the child in isolation, then place/clip it into the frame box.
        let childCanvas = TerminalCanvas(width: 0, height: 0)
        draw(child, into: childCanvas, at: .zero, axis: .vertical, proposedWidth: r.childProposedWidth, lineLimit: lineLimit)
        let block = composeFrameBlock(childCanvas.lines(), width: r.width, height: r.height, alignment: alignment)

        canvas.expand(toFit: Rect(origin: origin, size: Size(width: r.width, height: r.height)))
        for (row, line) in block.enumerated() where !line.isEmpty {
            canvas.write(line, at: Point(column: origin.column, row: origin.row + row))
        }
    }

    /// Positions `childLines` inside a `width` × `height` box per `alignment`,
    /// padding when the box is larger and clipping when it is smaller.
    static func composeFrameBlock(_ childLines: [String], width: Int, height: Int, alignment: Alignment) -> [String] {
        // Vertical placement.
        var rows: [String]
        if childLines.count <= height {
            let extra = height - childLines.count
            let topPad: Int
            switch alignment.vertical {
            case .top:    topPad = 0
            case .center: topPad = extra / 2
            case .bottom: topPad = extra
            }
            rows = Array(repeating: "", count: topPad) + childLines + Array(repeating: "", count: extra - topPad)
        } else {
            let over = childLines.count - height
            let start: Int
            switch alignment.vertical {
            case .top:    start = 0
            case .center: start = over / 2
            case .bottom: start = over
            }
            rows = Array(childLines[start..<(start + height)])
        }

        // Horizontal placement, then clip each row to the box width.
        return rows.map { line in
            let lineWidth = TextMetrics.visibleWidth(TextMetrics.stripANSI(line))
            if lineWidth >= width { return TextMetrics.truncate(line, toColumns: width) }
            let extra = width - lineWidth
            let leftPad: Int
            switch alignment.horizontal {
            case .leading:  leftPad = 0
            case .center:   leftPad = extra / 2
            case .trailing: leftPad = extra
            }
            return String(repeating: " ", count: leftPad) + line
        }
    }

    // MARK: - Leaf helpers

    private static func isDivider(_ node: RenderNode) -> Bool {
        if case .divider = node { return true }
        return false
    }

    /// The ANSI conceal sequence emitted by ``View/hidden()``. Rather than rely
    /// on the terminal's spotty support for conceal, SwiftLI treats this code
    /// as a marker: any leaf whose style header carries it is drawn as blank
    /// spaces of the same width.
    static let hiddenCode = "\u{001B}[8m"

    /// Returns `true` when a style header requests hiding.
    static func isHidden(_ header: String) -> Bool {
        header.contains(hiddenCode)
    }

    /// Replaces every visible glyph in a (possibly styled) string with spaces,
    /// preserving each character's column width and any line breaks.
    ///
    /// Wide characters collapse to two spaces so the surrounding layout keeps
    /// its exact geometry — hiding never changes where anything sits.
    static func blankedGlyphs(of styled: String) -> String {
        let plain = TextMetrics.stripANSI(styled)
        var out = ""
        for ch in plain {
            if ch == "\n" {
                out.append("\n")
            } else {
                out.append(String(repeating: " ", count: TextMetrics.visibleWidth(String(ch))))
            }
        }
        return out
    }

    /// Composes the final styled string for a text node: every content run
    /// gets the header prefix and an ANSI reset suffix.
    ///
    /// When `proposedWidth` is given, each logical line that exceeds it is word
    /// wrapped onto extra visual lines; `lineLimit` then caps the number of
    /// visual lines, marking the last kept line with an ellipsis when content is
    /// dropped. With neither constraint this returns the historical, unwrapped
    /// composition unchanged.
    static func styledText(header: String, contents: [String], proposedWidth: Int? = nil, lineLimit: Int? = nil) -> String {
        // Fast path preserves exact legacy output when nothing constrains us.
        if proposedWidth == nil && lineLimit == nil {
            return contents.map { header + $0 + "\u{001B}[0m" }.joined()
        }

        let logical = contents.joined().components(separatedBy: "\n")
        var visual: [String] = []
        for line in logical {
            if let w = proposedWidth, w > 0, TextMetrics.visibleWidth(line) > w {
                visual.append(contentsOf: wrap(line, toColumns: w))
            } else {
                visual.append(line)
            }
        }

        if let limit = lineLimit, limit > 0, visual.count > limit {
            let overflowed = Array(visual.prefix(limit))
            var trimmed = overflowed
            trimmed[limit - 1] = withEllipsis(overflowed[limit - 1], toColumns: proposedWidth)
            visual = trimmed
        }

        return visual.map { header + $0 + "\u{001B}[0m" }.joined(separator: "\n")
    }

    /// Word-wraps a single (newline-free) line so no visual line exceeds
    /// `columns` visible columns. Breaks at the last space when possible and
    /// hard-breaks an over-long word or wide glyph otherwise.
    static func wrap(_ line: String, toColumns columns: Int) -> [String] {
        guard columns > 0 else { return [line] }
        var lines: [String] = []
        var current: [Character] = []
        var currentWidth = 0
        var lastSpace = -1   // index in `current` of the most recent space

        for ch in line {
            let w = TextMetrics.width(of: ch)
            if currentWidth + w > columns && !current.isEmpty {
                if lastSpace >= 0 && lastSpace < current.count - 1 {
                    // Break after the last space; carry the trailing word over.
                    let head = Array(current[0..<lastSpace])
                    let tail = Array(current[(lastSpace + 1)...])
                    lines.append(String(head))
                    current = tail
                    currentWidth = tail.reduce(0) { $0 + TextMetrics.width(of: $1) }
                } else {
                    lines.append(String(current))
                    current = []
                    currentWidth = 0
                }
                lastSpace = -1
            }
            if ch == " " { lastSpace = current.count }
            current.append(ch)
            currentWidth += w
        }
        if !current.isEmpty || lines.isEmpty { lines.append(String(current)) }
        return lines
    }

    /// Appends (or substitutes) an ellipsis to signal truncated content,
    /// keeping the result within `columns` when a width is known.
    private static func withEllipsis(_ line: String, toColumns columns: Int?) -> String {
        guard let columns, columns > 0 else { return line + "…" }
        if TextMetrics.visibleWidth(line) + 1 <= columns { return line + "…" }
        return TextMetrics.truncate(line, toColumns: columns - 1) + "…"
    }

    private static func drawHorizontalDivider(header: String, character: Character, width: Int, into canvas: TerminalCanvas, at origin: Point) {
        guard width > 0 else { return }
        canvas.expand(toFit: Rect(origin: origin, size: Size(width: width, height: 1)))
        // A hidden divider keeps its column span but shows only blank spaces.
        let cell = isHidden(header)
            ? String(repeating: " ", count: width)
            : header + String(repeating: character, count: width) + "\u{001B}[0m"
        canvas.write(cell, at: origin)
    }

    private static func drawVerticalDivider(header: String, character: Character, height: Int, into canvas: TerminalCanvas, at origin: Point) {
        guard height > 0 else { return }
        canvas.expand(toFit: Rect(origin: origin, size: Size(width: 1, height: height)))
        let cell = isHidden(header) ? " " : header + String(character) + "\u{001B}[0m"
        for row in 0..<height {
            canvas.write(cell, at: Point(column: origin.column, row: origin.row + row))
        }
    }

    /// Concatenates `.raw` payloads in tree order (used for the frame preamble).
    private static func collectRaw(_ node: RenderNode) -> String {
        switch node {
        case .raw(let s):
            return s
        case .group(let children):
            return children.map(collectRaw).joined()
        case .hstack(_, _, let children):
            return children.map(collectRaw).joined()
        case .vstack(_, _, let children):
            return children.map(collectRaw).joined()
        case .padding(_, _, let child):
            return collectRaw(child)
        case .frame(_, _, _, _, _, let child):
            return collectRaw(child)
        case .lineLimit(_, let child):
            return collectRaw(child)
        case .scroll(_, _, _, _, let child):
            return collectRaw(child)
        case .hscroll(_, _, _, _, let child):
            return collectRaw(child)
        case .border(_, _, _, let child):
            return collectRaw(child)
        case .shadow(_, let child):
            return collectRaw(child)
        case .viewThatFits(_, _, let candidates):
            return candidates.map(collectRaw).joined()
        case .empty, .text, .spacer, .divider:
            return ""
        }
    }
}

// MARK: - Text metrics

/// Text measurement helpers shared by the layout engine and the `View` extension.
enum TextMetrics {

    /// Computes the terminal ``Size`` of a rendered string.
    static func size(of text: String) -> Size {
        let plain = stripANSI(text)
        var lines = plain.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        let height = lines.count
        let width  = lines.map { visibleWidth($0) }.max() ?? 0
        return Size(width: width, height: height)
    }

    /// Strips ANSI escape sequences from a string, returning printable text only.
    ///
    /// Handles both CSI sequences (`\e[…m`, ending at their final byte) and OSC
    /// sequences (`\e]…`, ending at BEL or the ST terminator `\e\`) — the latter
    /// is what carries OSC 8 hyperlinks — so neither is ever counted as visible
    /// width.
    static func stripANSI(_ s: String) -> String {
        var result = ""
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "\u{001B}" {
                i = s.index(after: i)
                guard i < s.endIndex else { break }
                if s[i] == "]" {
                    // OSC: skip until BEL or the ST terminator (ESC \).
                    i = s.index(after: i)
                    while i < s.endIndex {
                        let c = s[i]
                        if c == "\u{0007}" { i = s.index(after: i); break }
                        if c == "\u{001B}" {
                            i = s.index(after: i)
                            if i < s.endIndex, s[i] == "\\" { i = s.index(after: i) }
                            break
                        }
                        i = s.index(after: i)
                    }
                } else {
                    // CSI (or other): skip up to and including the final 'm'.
                    while i < s.endIndex {
                        let c = s[i]
                        i = s.index(after: i)
                        if c == "m" { break }
                    }
                }
            } else {
                result.append(s[i])
                i = s.index(after: i)
            }
        }
        return result
    }

    /// Truncates a (possibly ANSI-styled) string so its **visible** width does
    /// not exceed `limit` columns.
    ///
    /// Escape sequences are copied verbatim (they occupy no columns); visible
    /// glyphs are counted, and a wide glyph that would straddle the limit is
    /// dropped rather than split. When anything is cut, an ANSI reset is
    /// appended so no style leaks past the truncation.
    ///
    /// The reactive renderers clip every line to the terminal width with this,
    /// so a line never wraps onto a second physical row — which would otherwise
    /// desynchronise the cursor arithmetic used to redraw in place.
    static func truncate(_ styled: String, toColumns limit: Int) -> String {
        if limit <= 0 { return "" }
        var out = ""
        var width = 0
        var truncated = false
        var i = styled.startIndex
        while i < styled.endIndex {
            let ch = styled[i]
            if ch == "\u{001B}" {
                // Copy the whole escape sequence verbatim (it occupies no
                // columns): CSI ends at its 'm'; OSC ends at BEL or ST (`\e\`).
                out.append(ch)
                i = styled.index(after: i)
                if i < styled.endIndex, styled[i] == "]" {
                    out.append(styled[i])
                    i = styled.index(after: i)
                    while i < styled.endIndex {
                        let c = styled[i]
                        out.append(c)
                        i = styled.index(after: i)
                        if c == "\u{0007}" { break }
                        if c == "\u{001B}" {
                            if i < styled.endIndex, styled[i] == "\\" {
                                out.append(styled[i])
                                i = styled.index(after: i)
                            }
                            break
                        }
                    }
                } else {
                    while i < styled.endIndex {
                        let c = styled[i]
                        out.append(c)
                        i = styled.index(after: i)
                        if c == "m" { break }
                    }
                }
            } else {
                let w = visibleWidth(String(ch))
                if width + w > limit { truncated = true; break }
                out.append(ch)
                width += w
                i = styled.index(after: i)
            }
        }
        if truncated { out += "\u{001B}[0m" }
        return out
    }

    /// Returns the `width`-column window of a (possibly styled) string starting
    /// at visible column `start`.
    ///
    /// Escape sequences (CSI and OSC) are always copied so the style/hyperlink
    /// state carries into the window even when the leading columns are skipped;
    /// visible glyphs are kept only when they fall entirely inside
    /// `start ..< start + width`. Used to horizontally scroll a row.
    static func sliceColumns(_ styled: String, from start: Int, width: Int) -> String {
        if width <= 0 { return "" }
        var out = ""
        var col = 0
        var i = styled.startIndex
        while i < styled.endIndex {
            let ch = styled[i]
            if ch == "\u{001B}" {
                // Copy the whole escape verbatim: CSI ends at 'm'; OSC at BEL/ST.
                out.append(ch)
                i = styled.index(after: i)
                if i < styled.endIndex, styled[i] == "]" {
                    out.append(styled[i]); i = styled.index(after: i)
                    while i < styled.endIndex {
                        let c = styled[i]; out.append(c); i = styled.index(after: i)
                        if c == "\u{0007}" { break }
                        if c == "\u{001B}" {
                            if i < styled.endIndex, styled[i] == "\\" { out.append(styled[i]); i = styled.index(after: i) }
                            break
                        }
                    }
                } else {
                    while i < styled.endIndex {
                        let c = styled[i]; out.append(c); i = styled.index(after: i)
                        if c == "m" { break }
                    }
                }
            } else {
                let w = visibleWidth(String(ch))
                if col >= start && col + w <= start + width {
                    out.append(ch)
                }
                col += w
                i = styled.index(after: i)
                if col >= start + width { break }
            }
        }
        out += "\u{001B}[0m"
        return out
    }

    /// Returns the visible column width of a string.
    ///
    /// Measurement is done per **grapheme cluster** (Swift `Character`), so a
    /// base letter plus combining marks counts once, an emoji — including
    /// multi-scalar ZWJ families and flag pairs — counts as two columns, and
    /// wide CJK / full-width characters count as two. This matches how a
    /// terminal advances the cursor for each glyph.
    static func visibleWidth(_ s: String) -> Int {
        s.reduce(0) { $0 + width(of: $1) }
    }

    /// The column width of a single grapheme cluster: `0` for a zero-width /
    /// combining-only cluster, `2` for emoji and wide CJK glyphs, otherwise `1`.
    static func width(of character: Character) -> Int {
        if isEmoji(character) { return 2 }

        guard let base = character.unicodeScalars.first else { return 0 }
        if isZeroWidth(base) { return 0 }
        return isWideScalar(base.value) ? 2 : 1
    }

    /// Whether a grapheme cluster renders as an emoji (double-width) glyph.
    ///
    /// Covers the four ways an emoji presents: a ZWJ sequence (family, roles),
    /// a regional-indicator flag pair, a scalar with default emoji presentation,
    /// and an emoji base followed by the emoji variation selector (`U+FE0F`).
    private static func isEmoji(_ character: Character) -> Bool {
        let scalars = character.unicodeScalars
        if scalars.contains(where: { $0.value == 0x200D }) { return true }        // ZWJ sequence
        if scalars.contains(where: { $0.value == 0xFE0F }) &&
           scalars.contains(where: { $0.properties.isEmoji }) { return true }      // base + VS16
        if scalars.allSatisfy({ (0x1F1E6...0x1F1FF).contains($0.value) }) &&
           scalars.count >= 2 { return true }                                      // flag (RI pair)
        return scalars.contains { $0.properties.isEmojiPresentation }              // default emoji
    }

    /// Zero-width scalars: combining marks that stand alone, and format /
    /// default-ignorable code points (ZWJ, ZWSP, variation selectors, …).
    private static func isZeroWidth(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.properties.isDefaultIgnorableCodePoint { return true }
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .enclosingMark, .format: return true
        default: return false
        }
    }

    /// Whether a scalar occupies two columns (East-Asian wide / full-width and
    /// the emoji/pictograph blocks), by code-point range.
    private static func isWideScalar(_ v: UInt32) -> Bool {
        (v >= 0x1100 && v <= 0x115F)      // Hangul Jamo
            || (v >= 0x2E80 && v <= 0x303E)   // CJK radicals, Kangxi
            || v == 0x3000                    // ideographic space
            || (v >= 0x3041 && v <= 0x33BF)   // Kana … CJK symbols
            || (v >= 0x33FF && v <= 0xA4CF)   // CJK Unified etc.
            || (v >= 0xAC00 && v <= 0xD7A3)   // Hangul syllables
            || (v >= 0xF900 && v <= 0xFAFF)   // CJK compatibility ideographs
            || (v >= 0xFE30 && v <= 0xFE4F)   // CJK compatibility forms
            || (v >= 0xFF00 && v <= 0xFF60)   // full-width forms
            || (v >= 0xFFE0 && v <= 0xFFE6)   // full-width signs
            || (v >= 0x1F300 && v <= 0x1FAFF) // emoji & pictographs
            || (v >= 0x20000 && v <= 0x3FFFD) // CJK Extension B and beyond
    }
}
