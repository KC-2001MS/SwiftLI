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
        /// Children are arranged left to right along the column axis.
        case horizontal
        /// Children are arranged top to bottom along the row axis.
        case vertical
    }

    // MARK: - Frame

    /// Lays out a node tree from the origin and captures the result as a ``Frame``.
    ///
    /// - Parameter proposedWidth: The width proposed to the root, so text
    ///   wraps to it (the session renderers pass the usable terminal width,
    ///   as SwiftUI proposes the window's width to the root view). `nil` —
    ///   the one-shot default — lays the tree out at its natural width.
    public static func frame(of node: RenderNode, proposedWidth: Int? = nil) -> Frame {
        // A one-shot layout is its own render pass (a renderer that already
        // opened one simply continues it): measurements and the terminal
        // size are cached for its duration.
        RenderPassContext.withPass {
            let canvas = TerminalCanvas(width: 0, height: 0)
            draw(node, into: canvas, at: .zero, axis: .vertical, proposedWidth: proposedWidth)
            let rows = canvas.cellRows()
            var frame = Frame(preamble: collectRaw(node), lines: rows.map { TerminalCanvas.emit($0[...]) })
            frame.rows = rows
            return frame
        }
    }

    /// Measures a container through the pass-wide cache when one is active,
    /// recording its children's sizes alongside so drawing it needs no
    /// further lookups.
    private static func memoized(_ children: [RenderNode], kind: UInt8, spacing: Int, proposedWidth: Int?, lineLimit: Int?, compute: () -> LayoutMeasureCache.Entry) -> Size {
        guard let cache = RenderPassContext.current?.layoutCache else { return compute().size }
        let key = LayoutMeasureCache.key(for: children, kind: kind, spacing: spacing, proposedWidth: proposedWidth)
        return cache.entry(for: key, lineLimit: lineLimit, children: children, compute: compute).size
    }

    /// The children's sizes recorded when the container was measured in this
    /// pass, or `nil` when it hasn't been (or no pass is active).
    private static func cachedChildSizes(_ children: [RenderNode], kind: UInt8, spacing: Int, proposedWidth: Int?, lineLimit: Int?) -> [Size]? {
        guard let cache = RenderPassContext.current?.layoutCache else { return nil }
        let key = LayoutMeasureCache.key(for: children, kind: kind, spacing: spacing, proposedWidth: proposedWidth)
        return cache.entry(for: key, lineLimit: lineLimit)?.childSizes
    }

    /// What `node`'s measurement is sensitive to: whether a flexible spacer
    /// inside it reads the `maxWidth` / `maxHeight` environment, and the most
    /// visual lines any text inside it renders (a line limit below that
    /// changes the result). Nested containers answer from their cache entry
    /// when they have one; a nested `.lineLimit` shields its subtree from the
    /// limit outside it.
    private static func structure(of node: RenderNode, proposedWidth: Int?) -> LayoutMeasureCache.Structure {
        switch node {
        case .spacer:
            return LayoutMeasureCache.Structure(dependsOnEnvironment: true, maxVisualLines: 0)
        case .empty, .raw, .divider:
            return .leaf
        case .text(_, let contents):
            return LayoutMeasureCache.Structure(dependsOnEnvironment: false, maxVisualLines: visualLineCount(contents: contents, proposedWidth: proposedWidth))
        case .group(let children), .vstack(_, _, let children):
            if let known = RenderPassContext.current?.layoutCache.structure(of: children) { return known }
            var merged = LayoutMeasureCache.Structure()
            for child in children { merged.merge(structure(of: child, proposedWidth: proposedWidth)) }
            return merged
        case .hstack(_, _, let children):
            if let known = RenderPassContext.current?.layoutCache.structure(of: children) { return known }
            var merged = LayoutMeasureCache.Structure()
            // A row proposes no width to its children (see `measureRow`).
            for child in children { merged.merge(structure(of: child, proposedWidth: nil)) }
            return merged
        case .lineLimit(_, let child):
            // The limit inside applies instead of the one outside.
            var inner = structure(of: child, proposedWidth: proposedWidth)
            inner.maxVisualLines = 0
            return inner
        case .padding(let insets, let child):
            return structure(of: child, proposedWidth: proposedWidth.map { $0 - insets.horizontal })
        case .frame(let width, _, let fillWidth, _, _, let child):
            let outer: Int? = width.map { Swift.max(0, $0) } ?? (fillWidth ? (proposedWidth ?? TerminalSize.current.columns) : nil)
            return structure(of: child, proposedWidth: outer)
        case .scroll(_, _, let bar, let width, let child):
            return structure(of: child, proposedWidth: scrollContentProposal(proposedWidth, bar: bar, width: width))
        case .control(_, let child), .background(_, let child):
            return structure(of: child, proposedWidth: proposedWidth)
        case .hscroll(_, _, _, _, let child):
            return structure(of: child, proposedWidth: nil)
        case .border(_, _, _, let child):
            return structure(of: child, proposedWidth: proposedWidth.map { Swift.max(0, $0 - 2) })
        case .shadow(_, let radius, let x, _, let child):
            let extra = ShadowGeometry.extraWidth(radius: radius, x: x)
            return structure(of: child, proposedWidth: proposedWidth.map { Swift.max(0, $0 - extra) })
        case .viewThatFits(_, _, let candidates):
            var merged = LayoutMeasureCache.Structure()
            for candidate in candidates { merged.merge(structure(of: candidate, proposedWidth: proposedWidth)) }
            return merged
        case .zstack(_, let children):
            var merged = LayoutMeasureCache.Structure()
            for child in children { merged.merge(structure(of: child, proposedWidth: proposedWidth)) }
            return merged
        case .overlay(_, let base, let layer, _):
            var merged = structure(of: base, proposedWidth: proposedWidth)
            merged.merge(structure(of: layer, proposedWidth: proposedWidth))
            return merged
        }
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
        case .text(let style, let contents):
            return textSize(style: style, contents: contents, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .spacer(_, let minLength):
            // The minimum footprint; a row with flexible spacers expands them
            // to the leftover width during row layout (see `measureRow`).
            return axis == .horizontal ? Size(width: minLength, height: 1) : Size(width: 0, height: minLength)
        case .divider(_, _, _, let count, let fillsWidth):
            // Placeholder size — the enclosing stack stretches the divider to
            // its full height (HStack) or width (VStack) during layout. A
            // width-filling divider reports the proposed (or terminal) width.
            if axis == .horizontal { return Size(width: 1, height: 1) }
            return Size(width: fillsWidth ? (proposedWidth ?? TerminalSize.current.columns) : count, height: 1)
        case .group(let children):
            return memoized(children, kind: 0, spacing: 0, proposedWidth: proposedWidth, lineLimit: lineLimit) {
                measureColumn(flatten(children), spacing: 0, proposedWidth: proposedWidth, lineLimit: lineLimit)
            }
        case .vstack(_, let spacing, let children):
            return memoized(children, kind: 1, spacing: spacing, proposedWidth: proposedWidth, lineLimit: lineLimit) {
                measureColumn(flatten(children), spacing: spacing, proposedWidth: proposedWidth, lineLimit: lineLimit)
            }
        case .hstack(_, let spacing, let children):
            // Horizontal width division isn't modelled, so children keep their
            // natural width (no wrapping) inside an HStack. Flexible spacers
            // absorb the leftover space up to the proposed/available width.
            return memoized(children, kind: 2, spacing: spacing, proposedWidth: proposedWidth, lineLimit: lineLimit) {
                measureRow(flatten(children), spacing: spacing, proposedWidth: proposedWidth, lineLimit: lineLimit)
            }
        case .padding(let insets, let child):
            let inner = proposedWidth.map { $0 - insets.horizontal }
            var size = measure(child, axis: axis, proposedWidth: inner, lineLimit: lineLimit)
            size.width += insets.horizontal
            size.height += insets.vertical
            return size
        case .frame(let width, let height, let fillWidth, let fillHeight, _, let child):
            let r = resolveFrame(width: width, height: height, fillWidth: fillWidth, fillHeight: fillHeight, child: child, proposedWidth: proposedWidth, lineLimit: lineLimit)
            return Size(width: r.width, height: r.height)
        case .lineLimit(let limit, let child):
            return measure(child, axis: axis, proposedWidth: proposedWidth, lineLimit: limit)
        case .scroll(_, let height, let bar, let width, let child):
            let childSize = measure(child, axis: .vertical, proposedWidth: scrollContentProposal(proposedWidth, bar: bar, width: width), lineLimit: lineLimit)
            let showBar = bar != nil && childSize.height > height
            // With a scrollbar, the viewport spans its allotted width so the
            // bar sits at the far edge; without one it hugs the content.
            let total = showBar ? Swift.max(childSize.width + 2, width ?? 0) : childSize.width
            return Size(width: total, height: height)
        case .hscroll(_, let extent, let bar, let height, let child):
            let childSize = measure(child, axis: .vertical, proposedWidth: nil, lineLimit: lineLimit)
            let showBar = bar != nil && childSize.width > extent
            // With a scrollbar, the viewport spans its allotted height so the
            // bar sits at the bottom edge; without one it hugs the content.
            let total = showBar ? Swift.max(childSize.height + 1, height ?? 0) : childSize.height
            return Size(width: extent, height: total)
        case .border(_, _, _, let child):
            // The box adds one column on each side and one row top and bottom.
            let inner = proposedWidth.map { Swift.max(0, $0 - 2) }
            let childSize = measure(child, axis: .vertical, proposedWidth: inner, lineLimit: lineLimit)
            return Size(width: childSize.width + 2, height: childSize.height + 2)
        case .shadow(_, let radius, let x, let y, let child):
            // The footprint holds both the child and the offset, grown shadow.
            let extraW = ShadowGeometry.extraWidth(radius: radius, x: x)
            let extraH = ShadowGeometry.extraHeight(radius: radius, y: y)
            let inner = proposedWidth.map { Swift.max(0, $0 - extraW) }
            let childSize = measure(child, axis: .vertical, proposedWidth: inner, lineLimit: lineLimit)
            guard childSize.width > 0, childSize.height > 0 else { return childSize }
            return Size(width: childSize.width + extraW, height: childSize.height + extraH)
        case .viewThatFits(let cw, let ch, let candidates):
            let chosen = fittingCandidate(candidates, checkWidth: cw, checkHeight: ch, proposedWidth: proposedWidth, lineLimit: lineLimit)
            return measure(chosen, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .control(_, let child):
            return measure(child, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .background(_, let child):
            // A background is layout-transparent: it paints the child's own
            // footprint.
            return measure(child, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .zstack(_, let children):
            // The footprint holds the largest child on each axis.
            var size = Size.zero
            for child in children {
                let s = measure(child, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit)
                size.width = Swift.max(size.width, s.width)
                size.height = Swift.max(size.height, s.height)
            }
            return size
        case .overlay(_, let base, _, _):
            // The layer never changes the base's footprint.
            return measure(base, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)
        }
    }

    // MARK: - Drawing

    /// Draws a node into `canvas` with its top-left corner at `origin`.
    ///
    /// `proposedWidth` and `lineLimit` flow down exactly as in ``measure(_:axis:proposedWidth:lineLimit:)``.
    public static func draw(_ node: RenderNode, into canvas: TerminalCanvas, at origin: Point, axis: Axis = .vertical, proposedWidth: Int? = nil, lineLimit: Int? = nil) {
        switch node {
        case .empty, .raw:
            return
        case .text(let style, let contents):
            // Plain runs take the direct route: their lines are written with
            // the style's escape parts attached, instead of being composed
            // into an escape-wrapped string that the canvas parses back.
            if let lines = plainLines(style: style, contents: contents, proposedWidth: proposedWidth, lineLimit: lineLimit) {
                canvas.expand(toFit: Rect(origin: origin, size: textSize(style: style, contents: contents, proposedWidth: proposedWidth, lineLimit: lineLimit)))
                canvas.write(lines: lines, sgr: style.sgrPrefix, link: style.linkOpenSequence, at: origin)
                return
            }
            let s = styledText(style: style, contents: contents, proposedWidth: proposedWidth, lineLimit: lineLimit)
            if s.isEmpty { return }
            canvas.expand(toFit: Rect(origin: origin, size: textSize(style: style, contents: contents, proposedWidth: proposedWidth, lineLimit: lineLimit)))
            // `hidden()` replaces the glyphs with spaces while preserving the
            // exact column width, so the layout never shifts — only the
            // visible characters disappear.
            canvas.write(style.isHidden ? blankedGlyphs(of: s) : s, at: origin)
        case .spacer(let style, let minLength):
            // A spacer inside a row is drawn (expanded) by `drawRow`; this
            // path only handles a spacer outside any stack, at its minimum.
            if axis == .horizontal {
                canvas.expand(toFit: Rect(origin: origin, size: Size(width: minLength, height: 1)))
                canvas.write(style.ansiPrefix + String(repeating: " ", count: minLength), at: origin)
            } else {
                // Vertical spacer: occupies blank rows only.
                canvas.expand(toFit: Rect(origin: origin, size: Size(width: 0, height: minLength)))
            }
        case .divider(let style, let character, let verticalCharacter, let count, let fillsWidth):
            // A divider outside of a stack falls back to its own count/height,
            // or the proposed/terminal width when it is width-filling.
            if axis == .horizontal {
                drawVerticalDivider(style: style, character: verticalCharacter, height: 1, into: canvas, at: origin)
            } else {
                let width = fillsWidth ? (proposedWidth ?? TerminalSize.current.columns) : count
                drawHorizontalDivider(style: style, character: character, width: width, into: canvas, at: origin)
            }
        case .group(let children):
            drawColumn(children, kind: 0, alignment: .leading, spacing: 0, into: canvas, at: origin, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .vstack(let alignment, let spacing, let children):
            drawColumn(children, kind: 1, alignment: alignment, spacing: spacing, into: canvas, at: origin, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .hstack(let alignment, let spacing, let children):
            drawRow(children, alignment: alignment, spacing: spacing, into: canvas, at: origin, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .padding(let insets, let child):
            canvas.expand(toFit: Rect(origin: origin, size: measure(node, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)))
            let childOrigin = Point(
                column: origin.column + insets.leading,
                row: origin.row + insets.top
            )
            let inner = proposedWidth.map { $0 - insets.horizontal }
            draw(child, into: canvas, at: childOrigin, axis: axis, proposedWidth: inner, lineLimit: lineLimit)
        case .frame(let width, let height, let fillWidth, let fillHeight, let alignment, let child):
            drawFrame(width: width, height: height, fillWidth: fillWidth, fillHeight: fillHeight, alignment: alignment, child: child, into: canvas, at: origin, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .lineLimit(let limit, let child):
            draw(child, into: canvas, at: origin, axis: axis, proposedWidth: proposedWidth, lineLimit: limit)
        case .scroll(let offset, let height, let bar, let width, let child):
            drawScroll(offset: offset, height: height, bar: bar, width: width, child: child, into: canvas, at: origin, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .hscroll(let offset, let extent, let bar, let height, let child):
            drawHScroll(offset: offset, extent: extent, bar: bar, height: height, child: child, into: canvas, at: origin, lineLimit: lineLimit)
        case .border(let style, let fill, let box, let child):
            drawBorder(style: style, fill: fill, box: box, child: child, into: canvas, at: origin, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .shadow(let style, let radius, let x, let y, let child):
            drawShadow(style: style, radius: radius, x: x, y: y, child: child, into: canvas, at: origin, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .viewThatFits(let cw, let ch, let candidates):
            let chosen = fittingCandidate(candidates, checkWidth: cw, checkHeight: ch, proposedWidth: proposedWidth, lineLimit: lineLimit)
            draw(chosen, into: canvas, at: origin, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .control(let id, let child):
            // Record where the control lands so pointer events can find it,
            // then draw the child unchanged.
            let size = measure(child, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)
            MouseTargetRegistry.shared.record(id: id, rect: Rect(origin: origin, size: size))
            MouseTargetRegistry.shared.withControl(id: id) {
                draw(child, into: canvas, at: origin, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)
            }
        case .background(let style, let child):
            // Paint the child's whole footprint first, so cells the child never
            // writes (padding, frame slack, stack spacing) carry the colour;
            // the child then draws on top.
            let size = measure(child, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)
            if size.width > 0, size.height > 0, !style.isPlain {
                canvas.expand(toFit: Rect(origin: origin, size: size))
                let row = style.ansiPrefix + String(repeating: " ", count: size.width) + "\u{001B}[0m"
                for r in 0..<size.height {
                    canvas.write(row, at: Point(column: origin.column, row: origin.row + r))
                }
            }
            draw(child, into: canvas, at: origin, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .zstack(let alignment, let children):
            let size = measure(node, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)
            canvas.expand(toFit: Rect(origin: origin, size: size))
            for child in children {
                drawLayer(child, in: Rect(origin: origin, size: size), alignment: alignment, into: canvas, proposedWidth: proposedWidth, lineLimit: lineLimit)
            }
        case .overlay(let alignment, let base, let layer, let behind):
            let size = measure(base, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)
            canvas.expand(toFit: Rect(origin: origin, size: size))
            let box = Rect(origin: origin, size: size)
            if behind {
                drawLayer(layer, in: box, alignment: alignment, into: canvas, proposedWidth: proposedWidth, lineLimit: lineLimit)
                draw(base, into: canvas, at: origin, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)
            } else {
                draw(base, into: canvas, at: origin, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit)
                drawLayer(layer, in: box, alignment: alignment, into: canvas, proposedWidth: proposedWidth, lineLimit: lineLimit)
            }
        }
    }

    /// Draws `layer` positioned by `alignment` inside `box` (a z-stack child
    /// or an overlay). The layer is rendered on its own canvas and only the
    /// written cells are copied, so whatever lies beneath shows through the
    /// cells it leaves blank; a layer larger than the box is clipped to it,
    /// keeping the aligned edge.
    private static func drawLayer(_ layer: RenderNode, in box: Rect, alignment: Alignment, into canvas: TerminalCanvas, proposedWidth: Int?, lineLimit: Int?) {
        let size = measure(layer, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit)
        guard size.width > 0, size.height > 0 else { return }
        let leftPad: Int
        switch alignment.horizontal {
        case .leading:  leftPad = 0
        case .center:   leftPad = (box.size.width - size.width) / 2
        case .trailing: leftPad = box.size.width - size.width
        }
        let topPad: Int
        switch alignment.vertical {
        case .top:    topPad = 0
        case .center: topPad = (box.size.height - size.height) / 2
        case .bottom: topPad = box.size.height - size.height
        }
        let layerOrigin = Point(column: box.origin.column + Swift.max(0, leftPad), row: box.origin.row + Swift.max(0, topPad))
        let layerCanvas = TerminalCanvas(width: 0, height: 0)
        MouseTargetRegistry.shared.withTransform(translation: layerOrigin, clip: box) {
            draw(layer, into: layerCanvas, at: .zero, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit)
        }
        let rows = layerCanvas.cellRows()
        let maxWidth = box.maxColumn - layerOrigin.column
        for (index, row) in rows.enumerated() {
            let y = layerOrigin.row + index
            guard y < box.maxRow else { break }
            // Copy only the written cells, run by run, so unwritten cells stay
            // transparent (a z-stack child does not blank what lies beneath).
            let clipped = FrameDiff.truncate(row, toColumns: maxWidth)
            var column = 0
            var run: [TerminalCell] = []
            var runStart = 0
            func flush() {
                guard !run.isEmpty else { return }
                canvas.write(cells: run, at: Point(column: layerOrigin.column + runStart, row: y))
                run.removeAll(keepingCapacity: true)
            }
            for cell in clipped {
                if cell.written {
                    if run.isEmpty { runStart = column }
                    run.append(cell)
                } else {
                    flush()
                }
                column += Int(cell.width)
            }
            flush()
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

    /// The width a vertical viewport proposes to its content: the proposal
    /// it received, less the column its scrollbar takes at the far edge of
    /// its allotted width — so wrapped text never runs under the bar.
    static func scrollContentProposal(_ proposedWidth: Int?, bar: ScrollBar?, width: Int?) -> Int? {
        guard let proposedWidth, bar != nil else { return proposedWidth }
        return Swift.max(0, Swift.min(proposedWidth, (width ?? proposedWidth) - 1))
    }

    /// The rows (relative to `node`'s top) occupied by the control `id`
    /// inside `node`, or `nil` when the node does not contain it. Nested
    /// viewports are not searched — their content scrolls independently.
    ///
    /// ``ScrollView`` uses it to bring a focused child or a `scrollTo(_:)`
    /// target into view; ``List`` uses the same walk for its rows' lines.
    static func rowRange(ofControl id: String, in node: RenderNode, proposedWidth: Int?, lineLimit: Int? = nil) -> Range<Int>? {
        switch node {
        case .control(let cid, let child):
            if cid == id {
                let height = measure(node, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit).height
                return 0..<Swift.max(1, height)
            }
            return rowRange(ofControl: id, in: child, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .group(let children):
            return rowRange(ofControl: id, inColumn: children, spacing: 0, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .vstack(_, let spacing, let children):
            return rowRange(ofControl: id, inColumn: children, spacing: spacing, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .hstack(_, _, let children):
            for child in flatten(children) {
                if let range = rowRange(ofControl: id, in: child, proposedWidth: nil, lineLimit: lineLimit) { return range }
            }
            return nil
        case .padding(let insets, let child):
            return rowRange(ofControl: id, in: child, proposedWidth: proposedWidth.map { $0 - insets.horizontal }, lineLimit: lineLimit)
                .map { ($0.lowerBound + insets.top)..<($0.upperBound + insets.top) }
        case .frame(let width, let height, let fillWidth, let fillHeight, _, let child):
            let r = resolveFrame(width: width, height: height, fillWidth: fillWidth, fillHeight: fillHeight, child: child, proposedWidth: proposedWidth, lineLimit: lineLimit)
            return rowRange(ofControl: id, in: child, proposedWidth: r.childProposedWidth, lineLimit: lineLimit)
                .map { $0.lowerBound..<Swift.min($0.upperBound, Swift.max($0.lowerBound + 1, r.height)) }
        case .lineLimit(let limit, let child):
            return rowRange(ofControl: id, in: child, proposedWidth: proposedWidth, lineLimit: limit)
        case .background(_, let child), .overlay(_, let child, _, _):
            return rowRange(ofControl: id, in: child, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .border(_, _, _, let child):
            return rowRange(ofControl: id, in: child, proposedWidth: proposedWidth.map { Swift.max(0, $0 - 2) }, lineLimit: lineLimit)
                .map { ($0.lowerBound + 1)..<($0.upperBound + 1) }
        case .shadow(_, let radius, let x, let y, let child):
            let inset = ShadowGeometry.leadingInset(radius: radius, offset: y)
            let extra = ShadowGeometry.extraWidth(radius: radius, x: x)
            return rowRange(ofControl: id, in: child, proposedWidth: proposedWidth.map { Swift.max(0, $0 - extra) }, lineLimit: lineLimit)
                .map { ($0.lowerBound + inset)..<($0.upperBound + inset) }
        case .zstack(_, let children):
            for child in children {
                if let range = rowRange(ofControl: id, in: child, proposedWidth: proposedWidth, lineLimit: lineLimit) { return range }
            }
            return nil
        case .viewThatFits(let cw, let ch, let candidates):
            let chosen = fittingCandidate(candidates, checkWidth: cw, checkHeight: ch, proposedWidth: proposedWidth, lineLimit: lineLimit)
            return rowRange(ofControl: id, in: chosen, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .scroll, .hscroll, .empty, .raw, .text, .spacer, .divider:
            return nil
        }
    }

    private static func rowRange(ofControl id: String, inColumn children: [RenderNode], spacing: Int, proposedWidth: Int?, lineLimit: Int?) -> Range<Int>? {
        var y = 0
        let flat = flatten(children)
        for (index, child) in flat.enumerated() {
            if let range = rowRange(ofControl: id, in: child, proposedWidth: proposedWidth, lineLimit: lineLimit) {
                return (y + range.lowerBound)..<(y + range.upperBound)
            }
            y += measure(child, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit).height
            if index < flat.count - 1 { y += spacing }
        }
        return nil
    }

    private static func drawScroll(offset: Int, height: Int, bar: ScrollBar?, width: Int?, child: RenderNode, into canvas: TerminalCanvas, at origin: Point, proposedWidth: Int?, lineLimit: Int?) {
        guard height > 0 else { return }
        let proposedWidth = scrollContentProposal(proposedWidth, bar: bar, width: width)

        // Lay the child out in full, then take a `height`-row vertical window.
        // The child draws at the origin of its own canvas, so control regions
        // recorded inside are mapped: shifted up by the (pre-computed) scroll
        // offset, placed at this viewport's origin, and clipped to its rows.
        let measuredHeight = measure(child, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit).height
        let hitOffset = Swift.min(Swift.max(offset, 0), Swift.max(0, measuredHeight - height))
        // Only the rows that can land in the viewport are materialised as
        // cells; the rows outside it are still fully laid out (so the content
        // height, every row's width and the hit regions stay exact) but are
        // never turned into cells or strings — the cost of scrolling no longer
        // grows with the rows that aren't shown.
        //
        // When the content is provably narrower than the viewport's allotted
        // width, the rows outside the window aren't even traversed: the only
        // thing their widths could influence is where the scrollbar column
        // lands, and that is pinned to the allotted width in that case. (A
        // control they contain would be clipped out of the hit regions anyway.)
        let cullsHiddenRows = bar != nil && measuredHeight > height && width != nil
            && drawnWidthBound(child, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit) <= (width ?? 0) - 1
        var childCanvas = TerminalCanvas(width: 0, height: 0, visibleRows: hitOffset..<(hitOffset + height), cullsHiddenRows: cullsHiddenRows)
        MouseTargetRegistry.shared.withTransform(
            translation: Point(column: origin.column, row: origin.row - hitOffset),
            clip: Rect(origin: origin, size: Size(width: Int.max / 4, height: height))
        ) {
            draw(child, into: childCanvas, at: .zero, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit)
        }
        var contentHeight = childCanvas.height
        var maxOffset = Swift.max(0, contentHeight - height)
        var clamped = Swift.min(Swift.max(offset, 0), maxOffset)
        if clamped != hitOffset {
            // The drawn height disagrees with the measured one — not expected,
            // but the window above was chosen from the measurement, so redraw
            // with the window the content actually calls for. The hit regions
            // were already recorded by the first draw and must not be doubled.
            childCanvas = TerminalCanvas(width: 0, height: 0, visibleRows: clamped..<(clamped + height), cullsHiddenRows: false)
            MouseTargetRegistry.shared.withRecordingSuppressed {
                draw(child, into: childCanvas, at: .zero, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit)
            }
            contentHeight = childCanvas.height
            maxOffset = Swift.max(0, contentHeight - height)
            clamped = Swift.min(Swift.max(offset, 0), maxOffset)
        }
        // The window's rows, in order (row 0 is content row `clamped`), as
        // cells: they are copied into the frame's canvas as they are, never
        // composed into strings and parsed back.
        let lines = childCanvas.cellRows()

        let contentWidth = childCanvas.lineWidths().max() ?? 0
        let scrollable = contentHeight > height
        let showBar = bar != nil && scrollable
        // Pin the bar to the far edge of the allotted width (never closer than
        // one blank column after the content). `contentWidth` is a column
        // *count*, so the first free column past it is `contentWidth` itself,
        // not `contentWidth + 1` — a caller (like `TextEditor`) that already
        // reserves exactly one trailing column for the bar draws content
        // `width - 1` columns wide, and the extra `+ 1` this used to have
        // pushed the bar one column past the last valid one, off-screen.
        let barColumn = Swift.max(contentWidth, (width ?? 0) - 1)

        let thumb = ScrollBar.thumb(length: height, viewport: height, content: contentHeight, offset: clamped)
        let barStyles = bar.map(Self.scrollBarStyles)

        canvas.expand(toFit: Rect(origin: origin, size: Size(width: showBar ? barColumn + 1 : contentWidth, height: height)))
        if showBar {
            Self.recordScrollBar(Rect(origin: Point(column: origin.column + barColumn, row: origin.row), size: Size(width: 1, height: height)))
        }
        for row in 0..<height {
            let contentRow = clamped + row
            if contentRow < contentHeight, row < lines.count {
                let line = lines[row]
                if !line.isEmpty { canvas.write(cells: line, at: Point(column: origin.column, row: origin.row + row)) }
            }
            if showBar, let barStyles {
                let inThumb = row >= thumb.start && row < thumb.start + thumb.size
                canvas.write(lines: [" "], sgr: inThumb ? barStyles.thumb : barStyles.track, link: "", at: Point(column: origin.column + barColumn, row: origin.row + row))
            }
        }
    }

    /// The SGR prefixes of a scrollbar's two cell kinds.
    ///
    /// Every vertical bar cell is a space painted with the thumb or track
    /// colour as its background. A background fills the whole cell — unlike
    /// a `█` glyph, which leaves the line spacing Terminal.app adds between
    /// rows uncovered — so the bar is one unbroken strip. The prefixes are
    /// formatted once per bar, not once per cell.
    private static func scrollBarStyles(_ bar: ScrollBar) -> (thumb: String, track: String) {
        (
            thumb: TextStyle(background: bar.thumb).sgrPrefix,
            track: TextStyle(background: bar.track).sgrPrefix
        )
    }

    /// Records a drawn scrollbar as the `scrollbar` sub-region of the control
    /// that owns the viewport, so the pointer can grab and drag its thumb.
    private static func recordScrollBar(_ rect: Rect) {
        guard let owner = MouseTargetRegistry.shared.enclosingControlID else { return }
        MouseTargetRegistry.shared.record(
            id: MouseTargetRegistry.regionID(control: owner, role: MouseTargetRegistry.scrollbarRole),
            rect: rect
        )
    }

    private static func drawHScroll(offset: Int, extent: Int, bar: ScrollBar?, height allottedHeight: Int?, child: RenderNode, into canvas: TerminalCanvas, at origin: Point, lineLimit: Int?) {
        guard extent > 0 else { return }

        // Lay the child out at its natural width, then take an `extent`-column
        // horizontal window of every row. Control regions recorded inside are
        // mapped like the vertical viewport's, along the other axis.
        let measuredWidth = measure(child, axis: .vertical, proposedWidth: nil, lineLimit: lineLimit).width
        let hitOffset = Swift.min(Swift.max(offset, 0), Swift.max(0, measuredWidth - extent))
        let childCanvas = TerminalCanvas(width: 0, height: 0)
        MouseTargetRegistry.shared.withTransform(
            translation: Point(column: origin.column - hitOffset, row: origin.row),
            clip: Rect(origin: origin, size: Size(width: extent, height: Int.max / 4))
        ) {
            draw(child, into: childCanvas, at: .zero, axis: .vertical, proposedWidth: nil, lineLimit: lineLimit)
        }
        // The content's rows as cells. The window is cut from them cell by
        // cell, so every glyph keeps its own column — including when a wide
        // neighbour straddling the window's edge is left out.
        let rows = childCanvas.cellRows()
        let contentHeight = rows.count
        let contentWidth = childCanvas.lineWidths().max() ?? 0
        let maxOffset = Swift.max(0, contentWidth - extent)
        let clamped = Swift.min(Swift.max(offset, 0), maxOffset)

        let scrollable = contentWidth > extent
        let showBar = bar != nil && scrollable
        // Pin the bar to the bottom edge of the allotted height (never above
        // the row after the content), as the vertical viewport pins its bar to
        // the far edge of its allotted width.
        let barRow = Swift.max(contentHeight, (allottedHeight ?? 0) - 1)

        let thumb = ScrollBar.thumb(length: extent, viewport: extent, content: contentWidth, offset: clamped)

        canvas.expand(toFit: Rect(origin: origin, size: Size(width: extent, height: showBar ? barRow + 1 : contentHeight)))
        for (row, cells) in rows.enumerated() {
            writeColumnWindow(cells, from: clamped, width: extent, into: canvas, at: Point(column: origin.column, row: origin.row + row))
        }
        if showBar, let bar {
            // A whole-cell fill would make this bar a full row tall — about
            // twice a vertical bar's one-column width — so it is a lower half
            // block in the thumb or track colour: half a row is close to one
            // column wide, and glyphs tile without gaps along a row.
            let thumbStyle = TextStyle(foreground: bar.thumb).sgrPrefix
            let trackStyle = TextStyle(foreground: bar.track).sgrPrefix
            Self.recordScrollBar(Rect(origin: Point(column: origin.column, row: origin.row + barRow), size: Size(width: extent, height: 1)))
            for col in 0..<extent {
                let inThumb = col >= thumb.start && col < thumb.start + thumb.size
                canvas.write(lines: ["▄"], sgr: inThumb ? thumbStyle : trackStyle, link: "", at: Point(column: origin.column + col, row: origin.row + barRow))
            }
        }
    }

    /// Writes the cells of `row` that lie entirely inside visible columns
    /// `start ..< start + width`, each at its own column of the window (a
    /// glyph straddling an edge is left out and its columns stay blank).
    private static func writeColumnWindow(_ row: [TerminalCell], from start: Int, width: Int, into canvas: TerminalCanvas, at origin: Point) {
        guard width > 0 else { return }
        let end = start + width
        var col = 0
        var run: [TerminalCell] = []
        var runStart = 0
        func flush() {
            guard !run.isEmpty else { return }
            canvas.write(cells: run, at: Point(column: origin.column + runStart - start, row: origin.row))
            run.removeAll(keepingCapacity: true)
        }
        for cell in row {
            let w = Int(cell.width)
            if w == 0 {
                // The continuation of a wide glyph travels with it.
                if !run.isEmpty { run.append(cell) }
                continue
            }
            if col >= start, col + w <= end {
                if run.isEmpty { runStart = col }
                run.append(cell)
            } else {
                flush()
            }
            col += w
            if col >= end { break }
        }
        flush()
    }

    // MARK: - Border & shadow layout

    /// Draws a box of box-drawing glyphs around `child`, placing the child one
    /// cell in from the top-left corner.
    private static func drawBorder(style: TextStyle, fill: TextStyle, box: BorderStyle, child: RenderNode, into canvas: TerminalCanvas, at origin: Point, proposedWidth: Int?, lineLimit: Int?) {
        let g = box.glyphs
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
        // The fill's attributes win over the border style's where both specify.
        let edge = fill.inheriting(style).ansiPrefix

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
        if !fill.isPlain && w > 0 && h > 0 {
            let fillRow = fill.ansiPrefix + String(repeating: " ", count: w) + reset
            for r in 0..<h {
                canvas.write(fillRow, at: Point(column: origin.column + 1, row: origin.row + 1 + r))
            }
        }

        // The child sits inside the box, inset by one cell. When filled, the
        // child inherits the fill so its text sits on the fill background too.
        let content = fill.isPlain ? child : child.applyingStyle(fill)
        draw(content, into: canvas, at: Point(column: origin.column + 1, row: origin.row + 1), axis: .vertical, proposedWidth: inner, lineLimit: lineLimit)
    }

    /// Draws the shadow of `child` — its rectangle grown by `radius` on every
    /// side and shifted by (`x`, `y`) — then draws the child on top, so only
    /// the part of the shadow the child does not cover shows.
    private static func drawShadow(style: TextStyle, radius: Int, x: Int, y: Int, child: RenderNode, into canvas: TerminalCanvas, at origin: Point, proposedWidth: Int?, lineLimit: Int?) {
        let extraW = ShadowGeometry.extraWidth(radius: radius, x: x)
        let extraH = ShadowGeometry.extraHeight(radius: radius, y: y)
        let inner = proposedWidth.map { Swift.max(0, $0 - extraW) }
        let childSize = measure(child, axis: .vertical, proposedWidth: inner, lineLimit: lineLimit)
        let w = childSize.width
        let h = childSize.height

        guard w > 0, h > 0 else {
            draw(child, into: canvas, at: origin, axis: .vertical, proposedWidth: inner, lineLimit: lineLimit)
            return
        }

        canvas.expand(toFit: Rect(origin: origin, size: Size(width: w + extraW, height: h + extraH)))

        // A shadow that reaches above or left of the child pushes the child
        // right/down inside the footprint so nothing lands before the origin.
        let childOrigin = Point(
            column: origin.column + ShadowGeometry.leadingInset(radius: radius, offset: x),
            row: origin.row + ShadowGeometry.leadingInset(radius: radius, offset: y)
        )
        let r = Swift.max(0, radius)
        let shadowRect = Rect(
            origin: Point(column: childOrigin.column + x - r, row: childOrigin.row + y - r),
            size: Size(width: w + 2 * r, height: h + 2 * r)
        )
        let childRect = Rect(origin: childOrigin, size: childSize)

        // A single shadow cell: a styled space so trailing shadow is not trimmed.
        // Only cells outside the child are painted, so the child's blank
        // cells stay transparent rather than taking the shadow colour.
        let cell = style.ansiPrefix + " " + "\u{001B}[0m"
        for row in shadowRect.origin.row..<(shadowRect.origin.row + shadowRect.size.height) {
            for column in shadowRect.origin.column..<(shadowRect.origin.column + shadowRect.size.width) {
                let point = Point(column: column, row: row)
                guard !childRect.contains(point) else { continue }
                canvas.write(cell, at: point)
            }
        }

        // The content draws on top, covering the shadow it overlaps.
        draw(child, into: canvas, at: childOrigin, axis: .vertical, proposedWidth: inner, lineLimit: lineLimit)
    }

    /// How a `.shadow` node's footprint grows around its child.
    ///
    /// The shadow rectangle is the child grown by `radius` and shifted by the
    /// offset, so on each axis the footprint gains whatever sticks out before
    /// the child (`radius - offset`, when positive) and after it
    /// (`radius + offset`, when positive).
    enum ShadowGeometry {
        static func leadingInset(radius: Int, offset: Int) -> Int {
            Swift.max(0, Swift.max(0, radius) - offset)
        }

        static func trailingOverhang(radius: Int, offset: Int) -> Int {
            Swift.max(0, Swift.max(0, radius) + offset)
        }

        static func extraWidth(radius: Int, x: Int) -> Int {
            leadingInset(radius: radius, offset: x) + trailingOverhang(radius: radius, offset: x)
        }

        static func extraHeight(radius: Int, y: Int) -> Int {
            leadingInset(radius: radius, offset: y) + trailingOverhang(radius: radius, offset: y)
        }
    }

    // MARK: - Stack layout

    /// Flattens transparent `.group` nodes so their children become direct
    /// children of the enclosing stack. `.empty` nodes are dropped.
    static func flatten(_ children: [RenderNode]) -> [RenderNode] {
        // Most stacks hold no transparent group or empty node: hand the array
        // back as is instead of rebuilding it.
        let needsFlattening = children.contains { node in
            switch node {
            case .group, .empty: return true
            default: return false
            }
        }
        guard needsFlattening else { return children }
        return children.flatMap { node -> [RenderNode] in
            switch node {
            case .group(let inner): return flatten(inner)
            case .empty: return []
            default: return [node]
            }
        }
    }

    /// Measures a column of (flattened) children, returning the stack's size
    /// together with each child's, so drawing can reuse them.
    private static func measureColumn(_ children: [RenderNode], spacing: Int, proposedWidth: Int? = nil, lineLimit: Int? = nil) -> LayoutMeasureCache.Entry {
        var maxWidth = 0
        var totalHeight = 0
        var hasSpacer = false
        var structure = LayoutMeasureCache.Structure()
        var childSizes: [Size] = []
        childSizes.reserveCapacity(children.count)
        for (i, child) in children.enumerated() {
            if case .spacer = child { hasSpacer = true }
            let size = measure(child, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit)
            childSizes.append(size)
            structure.merge(Self.structure(of: child, proposedWidth: proposedWidth))
            // Dividers span the full stack width, so they don't constrain it.
            if !isDivider(child) && size.width > maxWidth { maxWidth = size.width }
            totalHeight += size.height
            if i < children.count - 1 { totalHeight += spacing }
        }
        // Flexible spacers expand the column to the available height — the
        // `maxHeight` environment (the terminal height at the top level) —
        // mirroring how they fill a row's width inside an HStack.
        if hasSpacer {
            totalHeight = Swift.max(totalHeight, EnvironmentStack.current.maxHeight)
        }
        return LayoutMeasureCache.Entry(size: Size(width: maxWidth, height: totalHeight), childSizes: childSizes, structure: structure)
    }

    /// Measures a row of (flattened) children, returning the stack's size
    /// together with each child's, so drawing can reuse them.
    private static func measureRow(_ children: [RenderNode], spacing: Int, proposedWidth: Int? = nil, lineLimit: Int? = nil) -> LayoutMeasureCache.Entry {
        var totalWidth = 0
        var maxHeight = 0
        var hasSpacer = false
        var structure = LayoutMeasureCache.Structure()
        var childSizes: [Size] = []
        childSizes.reserveCapacity(children.count)
        for (i, child) in children.enumerated() {
            if case .spacer = child { hasSpacer = true }
            let size = measure(child, axis: .horizontal, lineLimit: lineLimit)
            childSizes.append(size)
            structure.merge(Self.structure(of: child, proposedWidth: nil))
            totalWidth += size.width
            if i < children.count - 1 { totalWidth += spacing }
            if size.height > maxHeight { maxHeight = size.height }
        }
        // Flexible spacers expand the row to the proposed width — or the
        // current `maxWidth` environment (the terminal width at the top
        // level) when nothing is proposed — mirroring SwiftUI's Spacer.
        if hasSpacer {
            totalWidth = Swift.max(totalWidth, proposedWidth ?? EnvironmentStack.current.maxWidth)
        }
        return LayoutMeasureCache.Entry(size: Size(width: totalWidth, height: maxHeight), childSizes: childSizes, structure: structure)
    }

    private static func drawColumn(
        _ original: [RenderNode],
        kind: UInt8,
        alignment: HorizontalAlignment,
        spacing: Int,
        into canvas: TerminalCanvas,
        at origin: Point,
        proposedWidth: Int? = nil,
        lineLimit: Int? = nil
    ) {
        let children = flatten(original)
        // The sizes recorded when the column was measured (reused for the
        // stack width, spacer allocation and drawing); measured here only if
        // the column somehow wasn't measured in this pass.
        let childSizes = cachedChildSizes(original, kind: kind, spacing: spacing, proposedWidth: proposedWidth, lineLimit: lineLimit)
            ?? children.map { measure($0, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit) }

        // Dividers span the stack, so they don't participate in the width.
        let stackWidth = zip(children, childSizes).map { child, size in
            isDivider(child) ? 0 : size.width
        }.max() ?? 0

        // Flexible spacers share the column's leftover rows up to the
        // available height, pushing the views around them apart — the
        // vertical counterpart of a spacer expanding inside an HStack.
        let spacerMins = children.compactMap { child -> Int? in
            if case .spacer(_, let minLength) = child { return minLength }
            return nil
        }
        var spacerHeights: [Int] = []
        if !spacerMins.isEmpty {
            var natural = 0
            for i in children.indices {
                natural += childSizes[i].height
                if i < children.count - 1 { natural += spacing }
            }
            var extra = Swift.max(0, EnvironmentStack.current.maxHeight - natural)
            for (i, minLength) in spacerMins.enumerated() {
                let share = extra / (spacerMins.count - i)
                spacerHeights.append(minLength + share)
                extra -= share
            }
        }

        var y = origin.row
        var spacerIndex = 0
        let culled = canvas.culledRows
        for (i, child) in children.enumerated() {
            let size = childSizes[i]
            var advance = size.height
            if case .divider(let style, let character, _, let count, let fillsWidth) = child {
                if let culled, !culled.overlaps(y..<(y + 1)) {
                    // Off-window: keep the footprint, skip the drawing.
                    canvas.expand(toFit: Rect(origin: Point(column: origin.column, row: y), size: Size(width: 0, height: 1)))
                } else {
                    let width = fillsWidth ? (proposedWidth ?? TerminalSize.current.columns) : (stackWidth > 0 ? stackWidth : count)
                    drawHorizontalDivider(style: style, character: character, width: width, into: canvas, at: Point(column: origin.column, row: y))
                }
            } else if case .spacer = child {
                let height = spacerHeights[spacerIndex]
                spacerIndex += 1
                canvas.expand(toFit: Rect(origin: Point(column: origin.column, row: y), size: Size(width: 0, height: height)))
                advance = height
            } else {
                let colOffset: Int
                switch alignment {
                case .leading:  colOffset = 0
                case .trailing: colOffset = stackWidth - size.width
                }
                let childOrigin = Point(column: origin.column + colOffset, row: y)
                canvas.expand(toFit: Rect(origin: childOrigin, size: size))
                if let culled, !culled.overlaps(y..<(y + Swift.max(size.height, 1))) {
                    // Off-window: nothing it draws can show, so don't draw it.
                } else {
                    draw(child, into: canvas, at: childOrigin, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit)
                }
            }
            y += advance
            if i < children.count - 1 { y += spacing }
        }
    }

    /// An upper bound on the visible width of any row `node` draws, measured
    /// from its origin.
    ///
    /// Drawing stays within the measured width everywhere except for one
    /// thing: a horizontal divider stretches to its stack's width (or the full
    /// proposed/terminal width) while contributing nothing to that stack's
    /// measured width. The bound is therefore the measured width plus the
    /// largest such overshoot found in the subtree. A scrolled viewport uses
    /// it to decide whether the rows it doesn't show can be skipped outright.
    static func drawnWidthBound(_ node: RenderNode, axis: Axis, proposedWidth: Int?, lineLimit: Int?) -> Int {
        measure(node, axis: axis, proposedWidth: proposedWidth, lineLimit: lineLimit).width
            + dividerOvershoot(node, proposedWidth: proposedWidth, lineLimit: lineLimit)
    }

    /// The most a horizontal divider anywhere in `node` can draw past the
    /// measured width of the column that holds it. Only containers are
    /// visited; leaves are never measured.
    private static func dividerOvershoot(_ node: RenderNode, proposedWidth: Int?, lineLimit: Int?) -> Int {
        switch node {
        case .empty, .raw, .text, .spacer, .divider, .frame, .hscroll:
            // Leaves draw at their measured width; a frame or horizontal
            // viewport clips its content to its own.
            return 0
        case .group(let children), .vstack(_, _, let children):
            var overshoot = 0
            var stackWidth: Int?
            for child in flatten(children) {
                if case .divider(_, _, _, let count, let fillsWidth) = child {
                    let width = stackWidth ?? measure(node, axis: .vertical, proposedWidth: proposedWidth, lineLimit: lineLimit).width
                    stackWidth = width
                    let drawn = fillsWidth ? (proposedWidth ?? TerminalSize.current.columns) : (width > 0 ? width : count)
                    overshoot = Swift.max(overshoot, drawn - width)
                } else {
                    overshoot = Swift.max(overshoot, dividerOvershoot(child, proposedWidth: proposedWidth, lineLimit: lineLimit))
                }
            }
            return overshoot
        case .hstack(_, _, let children):
            return flatten(children).reduce(0) { Swift.max($0, dividerOvershoot($1, proposedWidth: nil, lineLimit: lineLimit)) }
        case .padding(let insets, let child):
            return dividerOvershoot(child, proposedWidth: proposedWidth.map { $0 - insets.horizontal }, lineLimit: lineLimit)
        case .lineLimit(let limit, let child):
            return dividerOvershoot(child, proposedWidth: proposedWidth, lineLimit: limit)
        case .scroll(_, _, _, _, let child):
            return dividerOvershoot(child, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .border(_, _, _, let child):
            return dividerOvershoot(child, proposedWidth: proposedWidth.map { Swift.max(0, $0 - 2) }, lineLimit: lineLimit)
        case .shadow(_, let radius, let x, _, let child):
            let extra = ShadowGeometry.extraWidth(radius: radius, x: x)
            return dividerOvershoot(child, proposedWidth: proposedWidth.map { Swift.max(0, $0 - extra) }, lineLimit: lineLimit)
        case .viewThatFits(let cw, let ch, let candidates):
            let chosen = fittingCandidate(candidates, checkWidth: cw, checkHeight: ch, proposedWidth: proposedWidth, lineLimit: lineLimit)
            return dividerOvershoot(chosen, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .control(_, let child), .background(_, let child):
            return dividerOvershoot(child, proposedWidth: proposedWidth, lineLimit: lineLimit)
        case .zstack(_, let children):
            return children.reduce(0) { Swift.max($0, dividerOvershoot($1, proposedWidth: proposedWidth, lineLimit: lineLimit)) }
        case .overlay(_, let base, let layer, _):
            return Swift.max(dividerOvershoot(base, proposedWidth: proposedWidth, lineLimit: lineLimit), dividerOvershoot(layer, proposedWidth: proposedWidth, lineLimit: lineLimit))
        }
    }

    private static func drawRow(
        _ original: [RenderNode],
        alignment: VerticalAlignment,
        spacing: Int,
        into canvas: TerminalCanvas,
        at origin: Point,
        proposedWidth: Int? = nil,
        lineLimit: Int? = nil
    ) {
        let children = flatten(original)
        // The sizes recorded when the row was measured (reused for the stack
        // height, spacer allocation and drawing); measured here only if the
        // row somehow wasn't measured in this pass.
        let childSizes = cachedChildSizes(original, kind: 2, spacing: spacing, proposedWidth: proposedWidth, lineLimit: lineLimit)
            ?? children.map { measure($0, axis: .horizontal, lineLimit: lineLimit) }

        // Dividers stretch to the stack height, so they don't participate in it.
        let stackHeight = zip(children, childSizes).map { child, size in
            isDivider(child) ? 0 : size.height
        }.max() ?? 0

        // Flexible spacers share the row's leftover space up to the proposed
        // (or top-level) width, so `HStack { Text("L"); Spacer(); Text("R") }`
        // pushes its children apart — mirroring SwiftUI. Each spacer gets its
        // minimum length plus an even share of the leftover.
        let spacerMins = children.compactMap { child -> Int? in
            if case .spacer(_, let minLength) = child { return minLength }
            return nil
        }
        var spacerWidths: [Int] = []
        if !spacerMins.isEmpty {
            var natural = 0
            for i in children.indices {
                natural += childSizes[i].width
                if i < children.count - 1 { natural += spacing }
            }
            let target = proposedWidth ?? EnvironmentStack.current.maxWidth
            var extra = Swift.max(0, target - natural)
            for (i, minLength) in spacerMins.enumerated() {
                let share = extra / (spacerMins.count - i)
                spacerWidths.append(minLength + share)
                extra -= share
            }
        }

        var x = origin.column
        var spacerIndex = 0
        let culled = canvas.culledRows
        for (i, child) in children.enumerated() {
            let size = childSizes[i]
            var advance = size.width
            if case .divider(let style, _, let verticalCharacter, _, _) = child {
                let rows = Swift.max(stackHeight, 1)
                if let culled, !culled.overlaps(origin.row..<(origin.row + rows)) {
                    canvas.expand(toFit: Rect(origin: Point(column: x, row: origin.row), size: Size(width: 1, height: rows)))
                } else {
                    drawVerticalDivider(style: style, character: verticalCharacter, height: rows, into: canvas, at: Point(column: x, row: origin.row))
                }
            } else if case .spacer(let style, _) = child {
                let width = spacerWidths[spacerIndex]
                spacerIndex += 1
                let childOrigin = Point(column: x, row: origin.row)
                canvas.expand(toFit: Rect(origin: childOrigin, size: Size(width: width, height: 1)))
                canvas.write(style.ansiPrefix + String(repeating: " ", count: width), at: childOrigin)
                advance = width
            } else {
                let rowOffset: Int
                switch alignment {
                case .top:    rowOffset = 0
                case .bottom: rowOffset = stackHeight - size.height
                }
                let childOrigin = Point(column: x, row: origin.row + rowOffset)
                canvas.expand(toFit: Rect(origin: childOrigin, size: size))
                if let culled, !culled.overlaps(childOrigin.row..<(childOrigin.row + Swift.max(size.height, 1))) {
                    // Off-window: nothing it draws can show, so don't draw it.
                } else {
                    draw(child, into: canvas, at: childOrigin, axis: .horizontal, lineLimit: lineLimit)
                }
            }
            x += advance
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
        // Control regions recorded inside are shifted by the block placement
        // that `composeFrameBlock` applies and clipped to the box. Horizontal
        // placement is per-line there; the block-level offset (from the child's
        // overall width) matches it exactly for leading alignment and for
        // uniform-width content, which covers the practical cases.
        let childSize = measure(child, axis: .vertical, proposedWidth: r.childProposedWidth, lineLimit: lineLimit)
        let topPad: Int
        switch alignment.vertical {
        case .top:    topPad = 0
        case .center: topPad = (r.height - childSize.height) / 2
        case .bottom: topPad = r.height - childSize.height
        }
        let leftPad: Int
        if childSize.width >= r.width {
            leftPad = 0
        } else {
            switch alignment.horizontal {
            case .leading:  leftPad = 0
            case .center:   leftPad = (r.width - childSize.width) / 2
            case .trailing: leftPad = r.width - childSize.width
            }
        }
        let childCanvas = TerminalCanvas(width: 0, height: 0)
        MouseTargetRegistry.shared.withTransform(
            translation: Point(column: origin.column + leftPad, row: origin.row + topPad),
            clip: Rect(origin: origin, size: Size(width: r.width, height: r.height))
        ) {
            draw(child, into: childCanvas, at: .zero, axis: .vertical, proposedWidth: r.childProposedWidth, lineLimit: lineLimit)
        }
        canvas.expand(toFit: Rect(origin: origin, size: Size(width: r.width, height: r.height)))
        placeFrameBlock(childCanvas.cellRows(), width: r.width, height: r.height, alignment: alignment, into: canvas, at: origin)
    }

    /// Positions the child's rows (as cells) inside a `width` × `height` box
    /// per `alignment` and writes them into `canvas` at `origin` — the cell
    /// form of ``composeFrameBlock(_:width:height:alignment:)``, which it
    /// matches row for row: the same rows are kept, each is clipped to the
    /// box or preceded by the same run of written blank cells, and no
    /// escape text is composed or parsed on the way.
    static func placeFrameBlock(_ childRows: [[TerminalCell]], width: Int, height: Int, alignment: Alignment, into canvas: TerminalCanvas, at origin: Point) {
        // Vertical placement.
        let topPad: Int
        let start: Int
        if childRows.count <= height {
            let extra = height - childRows.count
            switch alignment.vertical {
            case .top:    topPad = 0
            case .center: topPad = extra / 2
            case .bottom: topPad = extra
            }
            start = 0
        } else {
            let over = childRows.count - height
            switch alignment.vertical {
            case .top:    start = 0
            case .center: start = over / 2
            case .bottom: start = over
            }
            topPad = 0
        }

        // Horizontal placement, then clip each row to the box width.
        for row in 0..<height {
            let childIndex = row - topPad + start
            let cells = (childIndex >= 0 && childIndex < childRows.count && childIndex - start < height) ? childRows[childIndex] : []
            let point = Point(column: origin.column, row: origin.row + row)
            var lineWidth = 0
            for cell in cells { lineWidth += Int(cell.width) }
            if lineWidth >= width {
                canvas.write(cells: FrameDiff.truncate(cells, toColumns: width), at: point)
                continue
            }
            let extra = width - lineWidth
            let leftPad: Int
            switch alignment.horizontal {
            case .leading:  leftPad = 0
            case .center:   leftPad = extra / 2
            case .trailing: leftPad = extra
            }
            if leftPad > 0 {
                canvas.write(lines: [String(repeating: " ", count: leftPad)], sgr: "", link: "", at: point)
            }
            if !cells.isEmpty {
                canvas.write(cells: cells, at: Point(column: origin.column + leftPad, row: origin.row + row))
            }
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
    /// gets the style's escape prefix and an ANSI reset suffix. This — together
    /// with the divider/spacer/border/shadow helpers below — is where the
    /// engine lowers the IR's structured ``TextStyle`` to concrete output.
    ///
    /// When `proposedWidth` is given, each logical line that exceeds it is word
    /// wrapped onto extra visual lines; `lineLimit` then caps the number of
    /// visual lines, marking the last kept line with an ellipsis when content is
    /// dropped. With neither constraint this returns the historical, unwrapped
    /// composition unchanged.
    static func styledText(style: TextStyle, contents: [String], proposedWidth: Int? = nil, lineLimit: Int? = nil) -> String {
        let prefix = style.ansiPrefix
        // Fast path preserves exact legacy output when nothing constrains us.
        if proposedWidth == nil && lineLimit == nil {
            return contents.map { prefix + $0 + "\u{001B}[0m" }.joined()
        }
        return visualLines(of: contents, proposedWidth: proposedWidth, lineLimit: lineLimit, alignment: style.textAlignment ?? .leading, truncation: style.truncationMode ?? .tail)
            .map { prefix + $0 + "\u{001B}[0m" }
            .joined(separator: "\n")
    }

    /// The visual lines a text node renders under a width proposal and line
    /// limit: logical lines split on newlines, word-wrapped to the width, then
    /// capped (with an ellipsis on the last kept line) by the limit.
    static func visualLines(of contents: [String], proposedWidth: Int?, lineLimit: Int?, alignment: TextAlignment = .leading, truncation: Text.TruncationMode = .tail) -> [String] {
        let logical = contents.joined().components(separatedBy: "\n")
        var visual: [String] = []
        for line in logical {
            if let w = proposedWidth, w > 0, TextMetrics.visibleWidth(TextMetrics.stripANSI(line)) > w {
                visual.append(contentsOf: wrap(line, toColumns: w))
            } else {
                visual.append(line)
            }
        }

        if let limit = lineLimit, limit > 0, visual.count > limit {
            let kept = Array(visual.prefix(limit))
            var trimmed = kept
            switch truncation {
            case .tail:
                trimmed[limit - 1] = withEllipsis(kept[limit - 1], toColumns: proposedWidth)
            case .head, .middle:
                // The dropped lines fold into the last kept line, which is
                // then cut at its start (head) or its centre (middle) so the
                // end of the text stays visible.
                let rest = visual.dropFirst(limit).joined(separator: " ")
                let whole = kept[limit - 1] + (rest.isEmpty ? "" : " " + rest)
                let columns = proposedWidth ?? Swift.max(1, TextMetrics.visibleWidth(TextMetrics.stripANSI(kept[limit - 1])))
                trimmed[limit - 1] = truncation == .head
                    ? truncateHead(whole, toColumns: columns)
                    : truncateMiddle(whole, toColumns: columns)
            default:
                trimmed[limit - 1] = withEllipsis(kept[limit - 1], toColumns: proposedWidth)
            }
            visual = trimmed
        }

        if alignment != .leading, visual.count > 1 {
            // Pad the shorter lines so every line aligns within the text's
            // own width (the widest line), as SwiftUI aligns wrapped lines.
            let widths = visual.map { TextMetrics.visibleWidth(TextMetrics.stripANSI($0)) }
            let target = widths.max() ?? 0
            visual = zip(visual, widths).map { line, width in
                let extra = target - width
                guard extra > 0 else { return line }
                let left = alignment == .center ? extra / 2 : extra
                return String(repeating: " ", count: left) + line
            }
        }
        return visual
    }

    /// Keeps the last `columns - 1` visible columns of `line` behind a
    /// leading ellipsis.
    private static func truncateHead(_ line: String, toColumns columns: Int) -> String {
        let width = TextMetrics.visibleWidth(TextMetrics.stripANSI(line))
        guard columns > 0 else { return "" }
        guard width + 1 > columns else { return "…" + line }
        let keep = Swift.max(0, columns - 1)
        return "…" + TextMetrics.sliceColumns(line, from: width - keep, width: keep)
    }

    /// Keeps the start and the end of `line` around a central ellipsis.
    private static func truncateMiddle(_ line: String, toColumns columns: Int) -> String {
        let width = TextMetrics.visibleWidth(TextMetrics.stripANSI(line))
        guard columns > 0 else { return "" }
        guard width + 1 > columns else { return line + "…" }
        let keep = Swift.max(0, columns - 1)
        let head = keep / 2
        let tail = keep - head
        return TextMetrics.truncate(line, toColumns: head) + "…" + TextMetrics.sliceColumns(line, from: width - tail, width: tail)
    }

    /// The rows a text node draws, as plain strings, when they can be written
    /// directly: the runs carry no escape sequences of their own, the style
    /// isn't hidden, and no line-limit ellipsis introduced a reset. `nil`
    /// sends the node down the composed-string route instead.
    static func plainLines(style: TextStyle, contents: [String], proposedWidth: Int?, lineLimit: Int?) -> [String]? {
        guard !style.isHidden, !contents.contains(where: { $0.utf8.contains(0x1B) }) else { return nil }
        let lines: [String]
        if proposedWidth == nil && lineLimit == nil {
            // No runs compose to "", which draws nothing.
            if contents.isEmpty { return [] }
            if contents.count == 1, !contents[0].utf8.contains(0x0A) {
                lines = contents
            } else {
                lines = contents.joined().components(separatedBy: "\n")
            }
        } else {
            lines = visualLines(of: contents, proposedWidth: proposedWidth, lineLimit: lineLimit, alignment: style.textAlignment ?? .leading, truncation: style.truncationMode ?? .tail)
            if lines.contains(where: { $0.utf8.contains(0x1B) }) { return nil }
        }
        return lines
    }

    /// How many visual lines a text node renders with no line limit: the
    /// number its measurement is sensitive to a limit below. The common case
    /// — a single line that fits the proposal — is answered without building
    /// the lines.
    static func visualLineCount(contents: [String], proposedWidth: Int?) -> Int {
        if !contents.contains(where: { $0.utf8.contains(0x0A) }) {
            guard let w = proposedWidth, w > 0 else { return 1 }
            let plain = TextMetrics.stripANSI(contents.count == 1 ? contents[0] : contents.joined())
            if TextMetrics.visibleWidth(plain) <= w { return 1 }
        }
        return visualLines(of: contents, proposedWidth: proposedWidth, lineLimit: nil).count
    }

    /// The size of a text node: exactly ``TextMetrics/size(of:)`` of its
    /// composed string, computed from the plain runs without composing the
    /// escape-wrapped string only to strip it again.
    static func textSize(style: TextStyle, contents: [String], proposedWidth: Int?, lineLimit: Int?) -> Size {
        // Runs that carry their own escape sequences (`Text + Text`, raw ANSI
        // in a string) take the literal route through the composed string.
        if contents.contains(where: { $0.utf8.contains(0x1B) }) {
            let s = styledText(style: style, contents: contents, proposedWidth: proposedWidth, lineLimit: lineLimit)
            return TextMetrics.size(of: s.isEmpty ? " " : s)
        }
        if proposedWidth == nil && lineLimit == nil {
            // No runs compose to "", which measures as a single blank cell.
            if contents.isEmpty { return Size(width: 1, height: 1) }
            return TextMetrics.plainSize(contents.count == 1 ? contents[0] : contents.joined())
        }
        // A single line that fits the proposal (the common case under the
        // root's width proposal) measures as a plain run — no wrapping pass.
        if (lineLimit ?? 1) >= 1, !contents.isEmpty, !contents.contains(where: { $0.utf8.contains(0x0A) || $0.isEmpty }) {
            let plain = contents.count == 1 ? contents[0] : contents.joined()
            if let w = proposedWidth, w > 0 {
                let width = TextMetrics.visibleWidth(plain)
                if width <= w { return Size(width: width, height: 1) }
            } else {
                return TextMetrics.plainSize(plain)
            }
        }
        // A line-limited last line may carry the reset that `truncate` appends
        // before its ellipsis, so this still strips (a no-op without escapes).
        let visual = visualLines(of: contents, proposedWidth: proposedWidth, lineLimit: lineLimit, alignment: style.textAlignment ?? .leading, truncation: style.truncationMode ?? .tail)
        return TextMetrics.size(of: visual.count == 1 ? visual[0] : visual.joined(separator: "\n"))
    }

    /// Word-wraps a single (newline-free) line so no visual line exceeds
    /// `columns` visible columns. Breaks at the last space when possible and
    /// hard-breaks an over-long word or wide glyph otherwise.
    static func wrap(_ line: String, toColumns columns: Int) -> [String] {
        guard columns > 0 else { return [line] }
        guard line.utf8.contains(0x1B) else { return wrapPlain(line, toColumns: columns) }
        return wrapStyled(line, toColumns: columns)
    }

    private static func wrapPlain(_ line: String, toColumns columns: Int) -> [String] {
        var lines: [String] = []
        var current: [Character] = []
        var currentWidth = 0
        var lastSpace = -1   // index in `current` of the most recent space

        for ch in line {
            let w = TextMetrics.width(of: ch)
            if currentWidth + w > columns && !current.isEmpty {
                if ch == " " {
                    // The line is full and the next character is the break
                    // itself: end the line here and drop the space.
                    lines.append(String(current))
                    current = []
                    currentWidth = 0
                    lastSpace = -1
                    continue
                }
                if lastSpace >= 0 {
                    // Break at the last space; carry the trailing word over.
                    let head = Array(current[0..<lastSpace])
                    let tail = lastSpace + 1 < current.count ? Array(current[(lastSpace + 1)...]) : []
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

    /// One piece of a styled line: a visible glyph or an escape sequence
    /// (which occupies no columns and travels with the text around it).
    private enum StyledToken {
        case glyph(Character, width: Int)
        case escape(String)
    }

    /// Splits a styled line into glyphs and whole escape sequences (CSI up to
    /// its final byte, OSC up to BEL or ST).
    private static func tokenize(_ line: String) -> [StyledToken] {
        var tokens: [StyledToken] = []
        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]
            guard ch == "\u{001B}" else {
                tokens.append(.glyph(ch, width: TextMetrics.width(of: ch)))
                i = line.index(after: i)
                continue
            }
            var sequence = String(ch)
            i = line.index(after: i)
            if i < line.endIndex, line[i] == "]" {
                sequence.append(line[i]); i = line.index(after: i)
                while i < line.endIndex {
                    let c = line[i]; sequence.append(c); i = line.index(after: i)
                    if c == "\u{0007}" { break }
                    if c == "\u{001B}" {
                        if i < line.endIndex, line[i] == "\\" { sequence.append(line[i]); i = line.index(after: i) }
                        break
                    }
                }
            } else {
                while i < line.endIndex {
                    let c = line[i]; sequence.append(c); i = line.index(after: i)
                    if c != "[", let scalar = c.unicodeScalars.first, scalar.value >= 0x40, scalar.value <= 0x7E { break }
                }
            }
            tokens.append(.escape(sequence))
        }
        return tokens
    }

    /// Word-wraps a line that carries escape sequences. Escapes never count
    /// toward the width, and the styles in force at a break are re-opened at
    /// the start of the continuation line, so a styled word keeps its look
    /// when it moves to the next row.
    private static func wrapStyled(_ line: String, toColumns columns: Int) -> [String] {
        let tokens = tokenize(line)
        var lines: [String] = []
        var current: [StyledToken] = []
        var currentWidth = 0
        var lastSpace = -1
        /// The SGR / link sequences still open after the given tokens.
        func activeEscapes(_ tokens: [StyledToken]) -> String {
            var active = ""
            for token in tokens {
                if case .escape(let sequence) = token {
                    if sequence == TextMetrics.reset { active = "" } else { active += sequence }
                }
            }
            return active
        }
        func render(_ tokens: [StyledToken]) -> String {
            var out = ""
            for token in tokens {
                switch token {
                case .glyph(let ch, _): out.append(ch)
                case .escape(let sequence): out += sequence
                }
            }
            return out
        }
        func width(_ tokens: [StyledToken]) -> Int {
            tokens.reduce(0) { if case .glyph(_, let w) = $1 { return $0 + w } else { return $0 } }
        }
        for token in tokens {
            guard case .glyph(let ch, let w) = token else {
                current.append(token)
                continue
            }
            if currentWidth + w > columns && currentWidth > 0 {
                if ch == " " {
                    // The line is full and the next glyph is the break: end
                    // the line, drop the space, carry the open styles over.
                    lines.append(render(current))
                    let carried = activeEscapes(current)
                    current = carried.isEmpty ? [] : [.escape(carried)]
                    currentWidth = 0
                    lastSpace = -1
                    continue
                }
                let carried: String
                if lastSpace >= 0 {
                    let head = Array(current[0..<lastSpace])
                    let tail = lastSpace + 1 < current.count ? Array(current[(lastSpace + 1)...]) : []
                    lines.append(render(head))
                    carried = activeEscapes(Array(current[0...lastSpace]))
                    current = tail
                } else {
                    lines.append(render(current))
                    carried = activeEscapes(current)
                    current = []
                }
                // The continuation re-opens the styles the previous line
                // left active.
                if !carried.isEmpty { current.insert(.escape(carried), at: 0) }
                currentWidth = width(current)
                lastSpace = -1
            }
            if ch == " " { lastSpace = current.count }
            current.append(token)
            currentWidth += w
        }
        if currentWidth > 0 || lines.isEmpty {
            lines.append(render(current))
        } else if !current.isEmpty, var last = lines.popLast() {
            // Trailing escapes (a closing reset) belong to the last line.
            last += render(current)
            lines.append(last)
        }
        return lines
    }

    /// Appends (or substitutes) an ellipsis to signal truncated content,
    /// keeping the result within `columns` when a width is known.
    private static func withEllipsis(_ line: String, toColumns columns: Int?) -> String {
        guard let columns, columns > 0 else { return line + "…" }
        if TextMetrics.visibleWidth(line) + 1 <= columns { return line + "…" }
        return TextMetrics.truncate(line, toColumns: columns - 1) + "…"
    }

    private static func drawHorizontalDivider(style: TextStyle, character: Character, width: Int, into canvas: TerminalCanvas, at origin: Point) {
        guard width > 0 else { return }
        canvas.expand(toFit: Rect(origin: origin, size: Size(width: width, height: 1)))
        // A hidden divider keeps its column span but shows only blank spaces.
        let cell = style.isHidden
            ? String(repeating: " ", count: width)
            : style.ansiPrefix + String(repeating: character, count: width) + "\u{001B}[0m"
        canvas.write(cell, at: origin)
    }

    private static func drawVerticalDivider(style: TextStyle, character: Character, height: Int, into canvas: TerminalCanvas, at origin: Point) {
        guard height > 0 else { return }
        canvas.expand(toFit: Rect(origin: origin, size: Size(width: 1, height: height)))
        let cell = style.isHidden ? " " : style.ansiPrefix + String(character) + "\u{001B}[0m"
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
        case .padding(_, let child):
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
        case .shadow(_, _, _, _, let child):
            return collectRaw(child)
        case .viewThatFits(_, _, let candidates):
            return candidates.map(collectRaw).joined()
        case .control(_, let child), .background(_, let child):
            return collectRaw(child)
        case .zstack(_, let children):
            return children.map(collectRaw).joined()
        case .overlay(_, let base, let layer, _):
            return collectRaw(base) + collectRaw(layer)
        case .empty, .text, .spacer, .divider:
            return ""
        }
    }
}

// MARK: - Text metrics

/// Text measurement helpers shared by the layout engine and the `View` extension.
enum TextMetrics {

    static let reset = "\u{001B}[0m"
    /// The ST-terminated close for an OSC 8 hyperlink.
    static let linkClose = "\u{001B}]8;;\u{001B}\\"

    /// Computes the terminal ``Size`` of a rendered string.
    static func size(of text: String) -> Size {
        plainSize(stripANSI(text))
    }

    /// The size of a string that carries no escape sequences: its logical
    /// lines (a trailing empty line is not counted) by the widest of them.
    static func plainSize(_ plain: String) -> Size {
        // One pass over the scalars settles the common case — a single line
        // of simple scalars — measuring it as it goes; a newline or a scalar
        // that needs the full checks falls through to the general paths.
        var simpleWidth = 0
        var simple = true
        for scalar in plain.unicodeScalars {
            if scalar.value == 0x0A { simple = false; break }
            guard let w = simpleScalarWidth(scalar.value) else { simple = false; break }
            simpleWidth += w
        }
        if simple {
            return plain.isEmpty ? .zero : Size(width: simpleWidth, height: 1)
        }
        // Without a newline byte there is exactly one logical line — the
        // string itself — or none at all when it is empty.
        if !plain.utf8.contains(0x0A) {
            return plain.isEmpty ? .zero : Size(width: visibleWidth(plain), height: 1)
        }
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
        let utf8 = s.utf8
        // Nothing to strip: hand back the same storage.
        guard utf8.contains(0x1B) else { return s }
        var result = ""
        result.reserveCapacity(utf8.count)
        let end = utf8.endIndex
        var chunkStart = utf8.startIndex
        var i = utf8.startIndex
        // Copy the printable stretches between sequences in one piece each
        // rather than character by character.
        while i < end {
            guard utf8[i] == 0x1B else { i = utf8.index(after: i); continue }
            result += s[chunkStart..<i]
            i = utf8.index(after: i)
            guard i < end else { chunkStart = end; break }
            if utf8[i] == 0x5D { // "]" — OSC: skip until BEL or the ST terminator (ESC \).
                i = utf8.index(after: i)
                while i < end {
                    let c = utf8[i]
                    if c == 0x07 { i = utf8.index(after: i); break }
                    if c == 0x1B {
                        i = utf8.index(after: i)
                        if i < end, utf8[i] == 0x5C { i = utf8.index(after: i) }
                        break
                    }
                    i = utf8.index(after: i)
                }
            } else {
                // CSI (or other): skip up to and including the final 'm'.
                while i < end {
                    let c = utf8[i]
                    i = utf8.index(after: i)
                    if c == 0x6D { break }
                }
            }
            chunkStart = i
        }
        if chunkStart < end { result += s[chunkStart..<end] }
        return result
    }

    /// Whether an OSC sequence (ESC included) is the OSC 8 hyperlink *close*
    /// (an empty URI), in either its ST- or BEL-terminated form.
    static func isLinkClose(_ sequence: Substring) -> Bool {
        guard sequence.hasPrefix("\u{001B}]8;;") else { return false }
        let terminator = sequence.dropFirst(5).first
        return terminator == "\u{001B}" || terminator == "\u{0007}"
    }

    /// Truncates a (possibly ANSI-styled) string so its **visible** width does
    /// not exceed `limit` columns.
    ///
    /// Escape sequences are copied verbatim (they occupy no columns); visible
    /// glyphs are counted, and a wide glyph that would straddle the limit is
    /// dropped rather than split. When anything is cut, an ANSI reset is
    /// appended so no style leaks past the truncation (and a hyperlink that
    /// was still open is closed).
    ///
    /// The reactive renderers clip every line to the terminal width with this,
    /// so a line never wraps onto a second physical row — which would otherwise
    /// desynchronise the cursor arithmetic used to redraw in place.
    static func truncate(_ styled: String, toColumns limit: Int) -> String {
        if limit <= 0 { return "" }
        // A line that already fits comes back untouched (the walk below would
        // only copy it), so the common case costs one width measurement.
        if visibleWidth(stripANSI(styled)) <= limit { return styled }
        var out = ""
        var width = 0
        var truncated = false
        var linkOpen = false
        var i = styled.startIndex
        while i < styled.endIndex {
            let ch = styled[i]
            if ch == "\u{001B}" {
                // Copy the whole escape sequence verbatim (it occupies no
                // columns): CSI ends at its 'm'; OSC ends at BEL or ST (`\e\`).
                let sequenceStart = i
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
                    linkOpen = !isLinkClose(styled[sequenceStart..<i])
                } else {
                    while i < styled.endIndex {
                        let c = styled[i]
                        out.append(c)
                        i = styled.index(after: i)
                        if c == "m" { break }
                    }
                }
            } else {
                let w = Self.width(of: ch)
                if width + w > limit { truncated = true; break }
                out.append(ch)
                width += w
                i = styled.index(after: i)
            }
        }
        if truncated {
            out += reset
            if linkOpen { out += linkClose }
        }
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
        var linkOpen = false
        var i = styled.startIndex
        while i < styled.endIndex {
            let ch = styled[i]
            if ch == "\u{001B}" {
                // Copy the whole escape verbatim: CSI ends at 'm'; OSC at BEL/ST.
                let sequenceStart = i
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
                    linkOpen = !isLinkClose(styled[sequenceStart..<i])
                } else {
                    while i < styled.endIndex {
                        let c = styled[i]; out.append(c); i = styled.index(after: i)
                        if c == "m" { break }
                    }
                }
            } else {
                let w = Self.width(of: ch)
                if col >= start && col + w <= start + width {
                    out.append(ch)
                }
                col += w
                i = styled.index(after: i)
                if col >= start + width { break }
            }
        }
        out += reset
        if linkOpen { out += linkClose }
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
        // Fast path: a string of "simple" scalars — ASCII, Latin, and the
        // common CJK blocks — is one cluster per scalar, each with a width
        // known from its code point alone (see `simpleScalarWidth`), so it
        // needs neither grapheme segmentation nor Unicode property lookups.
        var total = 0
        for scalar in s.unicodeScalars {
            guard let w = simpleScalarWidth(scalar.value) else {
                return s.reduce(0) { $0 + width(of: $1) }
            }
            total += w
        }
        return total
    }

    /// The column width of a scalar that always forms a cluster of its own
    /// and is never a combining mark, a format character, or an emoji — or
    /// `nil` when the scalar needs the full checks.
    ///
    /// Below U+0300 only two code points are excluded: CR (CR LF is the one
    /// all-ASCII pair that forms a single cluster) and the soft hyphen (a
    /// default-ignorable, so zero-width). The CJK ranges cover kana, CJK
    /// symbols, unified ideographs, Hangul syllables, and full-width forms,
    /// skipping the few combining marks among them (U+302A–U+302D, U+3099,
    /// U+309A).
    @inline(__always)
    static func simpleScalarWidth(_ v: UInt32) -> Int? {
        if v < 0x300 { return (v == 0x0D || v == 0xAD) ? nil : 1 }
        if (0x3000...0x3029).contains(v) || (0x302E...0x303E).contains(v)
            || (0x3041...0x3096).contains(v) || (0x30A1...0x30FF).contains(v)
            || (0x4E00...0x9FFF).contains(v) || (0xAC00...0xD7A3).contains(v)
            || (0xFF01...0xFF60).contains(v) {
            return 2
        }
        return nil
    }

    /// The column width of a single grapheme cluster: `0` for a zero-width /
    /// combining-only cluster, `2` for emoji and wide CJK glyphs, otherwise `1`.
    static func width(of character: Character) -> Int {
        // A single-byte cluster is one ASCII scalar: never emoji, never
        // zero-width, never wide.
        if character.utf8.count == 1 { return 1 }
        // A lone simple scalar (Latin, CJK) is known without property lookups.
        let scalars = character.unicodeScalars
        if let first = scalars.first,
           scalars.index(after: scalars.startIndex) == scalars.endIndex,
           let w = simpleScalarWidth(first.value) {
            return w
        }
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
