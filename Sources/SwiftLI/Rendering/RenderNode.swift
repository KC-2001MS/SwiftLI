//
//  RenderNode.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/06.
//

/// The colour palette of a scrollbar.
///
/// The bar is drawn as one continuous solid strip — full blocks for the thumb
/// and the track with no textured gaps. The thumb's ends land on half-cell
/// boundaries: they use the half blocks (`▀`/`▄` vertically, `▌`/`▐`
/// horizontally) with the thumb colour in the foreground and the track colour
/// in the background, so a single cell shows both sides of the boundary.
public struct ScrollBar: Equatable, Sendable {
    /// The colour of the thumb (the draggable indicator).
    public let thumb: Color
    /// The colour of the track the thumb travels along.
    public let track: Color

    /// Creates a scrollbar palette with the given thumb and track colours.
    ///
    /// - Parameters:
    ///   - thumb: The colour used to draw the draggable thumb indicator.
    ///   - track: The colour used to draw the track the thumb travels along.
    public init(thumb: Color, track: Color) {
        self.thumb = thumb
        self.track = track
    }
}

/// The intermediate representation (IR) of a view tree.
///
/// Every ``View`` lowers itself into a `RenderNode` tree via `makeNode()`.
/// The tree is a pure value: it can be measured, laid out, compared with the
/// tree of a previous render, and finally drawn — all without touching
/// stdout. This decoupling is what allows SwiftLI to understand *which part*
/// of the output changed and rewrite only that part.
///
/// Styling in the IR is carried as structured ``TextStyle`` values, never as
/// raw escape sequences; the rendering engine lowers them to ANSI output at
/// draw time.
///
/// The rendering pipeline is:
///
/// ```
/// View ──makeNode()──▶ RenderNode ──NodeLayout──▶ Frame ──FrameDiff──▶ stdout
/// ```
public indirect enum RenderNode: Equatable, Sendable {
    /// Renders nothing and occupies no space.
    case empty

    /// Styled text runs. Each element of `contents` is emitted with `style`
    /// applied and closed with a reset, joined on the same logical line
    /// (unless a content string itself contains newlines).
    case text(style: TextStyle, contents: [String])

    /// Flexible blank space. Inside an ``HStack`` it expands to absorb the
    /// row's leftover width, never shrinking below `minLength` columns.
    /// Everywhere else it occupies `minLength` blank rows.
    case spacer(style: TextStyle, minLength: Int)

    /// A separator: a vertical line inside an ``HStack``, a horizontal line
    /// everywhere else.
    ///
    /// When `fillsWidth` is `true` the horizontal line spans the full terminal
    /// width, recomputed at layout time. Otherwise the length is resolved by
    /// the enclosing stack, falling back to `count` when there is no stack to
    /// span.
    case divider(style: TextStyle, character: Character, verticalCharacter: Character, count: Int, fillsWidth: Bool)

    /// A transparent container. Children are flattened into the enclosing
    /// stack; at the top level they stack vertically with no spacing.
    case group(children: [RenderNode])

    /// Children laid out side-by-side, aligned to the top or bottom row.
    case hstack(alignment: VerticalAlignment, spacing: Int, children: [RenderNode])

    /// Children laid out top-to-bottom, aligned to the leading or trailing edge.
    case vstack(alignment: HorizontalAlignment, spacing: Int, children: [RenderNode])

    /// Blank space around a child, one amount per edge.
    case padding(insets: EdgeInsets, child: RenderNode)

    /// A fixed- or flexible-size box around a child.
    ///
    /// `width`/`height` give a definite size; `fillWidth`/`fillHeight` request
    /// filling the proposed (or terminal) extent instead. The resolved box
    /// proposes its width down to the child — so text inside wraps to it — then
    /// positions and clips the child according to `alignment`.
    case frame(width: Int?, height: Int?, fillWidth: Bool, fillHeight: Bool, alignment: Alignment, child: RenderNode)

    /// Limits the number of visual lines a descendant ``text`` renders,
    /// truncating the last kept line with an ellipsis when content overflows.
    case lineLimit(Int?, child: RenderNode)

    /// A fixed-height viewport showing a vertically scrolled window of a taller
    /// child.
    ///
    /// The child is laid out in full, then only the rows in
    /// `offset ..< offset + height` are drawn. `bar` colours the scrollbar
    /// (`nil` hides it). The bar is pinned to the right edge of `width` (the
    /// columns allotted to the viewport); a `nil` width places it just right
    /// of the content.
    case scroll(offset: Int, height: Int, bar: ScrollBar?, width: Int?, child: RenderNode)

    /// A box of Unicode box-drawing characters around a child.
    ///
    /// The border occupies one extra column on each side and one extra row
    /// above and below the child. `style` styles the border glyphs (e.g. a
    /// foreground colour); a plain style uses the terminal default. `fill`
    /// styles the interior — when specified the whole inside of the box is
    /// painted with it (typically a background colour) and the child inherits
    /// it so its text sits on the fill; a plain `fill` leaves the interior
    /// transparent.
    case border(style: TextStyle, fill: TextStyle, box: BorderStyle, child: RenderNode)

    /// A drop shadow drawn along a child's right and bottom edges.
    ///
    /// The shadow adds one column and one row to the footprint, offset a single
    /// cell down and to the right. `style` styles the shadow cells (typically a
    /// background colour).
    case shadow(style: TextStyle, child: RenderNode)

    /// A fixed-width viewport showing a horizontally scrolled window of a wider
    /// child.
    ///
    /// The child is laid out in full, then only the columns in
    /// `offset ..< offset + extent` of each row are drawn. `bar` colours the
    /// scrollbar drawn on the row below the content, at the bottom edge of the
    /// viewport; `nil` hides it.
    case hscroll(offset: Int, extent: Int, bar: ScrollBar?, child: RenderNode)

    /// Picks the first candidate whose natural size fits the available space.
    ///
    /// At layout time each candidate is measured at its natural (unconstrained)
    /// size and compared against the proposed width (and/or the terminal
    /// height); the first that fits is laid out, falling back to the last
    /// candidate when none do. `checkWidth`/`checkHeight` select which axes the
    /// fit is tested on.
    case viewThatFits(checkWidth: Bool, checkHeight: Bool, candidates: [RenderNode])

    /// A raw ANSI escape sequence emitted before the frame's grid content
    /// (e.g. a screen-clear sequence). Occupies no cells.
    case raw(String)

    /// Marks the subtree as the on-screen footprint of the interactive control
    /// `id` (the identity it registered with ``FocusCoordinator``).
    ///
    /// Layout-transparent: it measures and draws exactly as its child. At draw
    /// time the child's rectangle is recorded in ``MouseTargetRegistry`` so
    /// pointer events (clicks, the scroll wheel) can be routed to the control
    /// under the pointer.
    case control(id: String, child: RenderNode)

    /// Returns a copy of the tree with every styled leaf resolved against
    /// `style`.
    ///
    /// This is how container styles (modifiers applied to ``Group``,
    /// ``HStack``, or ``VStack``) cascade down to the text, spacer, and
    /// divider leaves: a leaf's own attributes win, unspecified ones inherit
    /// the container's.
    public func applyingStyle(_ style: TextStyle) -> RenderNode {
        guard !style.isPlain else { return self }
        switch self {
        case .empty, .raw:
            return self
        case .text(let s, let contents):
            return .text(style: s.inheriting(style).resolving(), contents: contents)
        case .spacer(let s, let minLength):
            return .spacer(style: s.inheriting(style).resolving(), minLength: minLength)
        case .divider(let s, let character, let verticalCharacter, let count, let fillsWidth):
            return .divider(style: s.inheriting(style).resolving(), character: character, verticalCharacter: verticalCharacter, count: count, fillsWidth: fillsWidth)
        case .group(let children):
            return .group(children: children.map { $0.applyingStyle(style) })
        case .hstack(let alignment, let spacing, let children):
            return .hstack(alignment: alignment, spacing: spacing, children: children.map { $0.applyingStyle(style) })
        case .vstack(let alignment, let spacing, let children):
            return .vstack(alignment: alignment, spacing: spacing, children: children.map { $0.applyingStyle(style) })
        case .padding(let insets, let child):
            return .padding(insets: insets, child: child.applyingStyle(style))
        case .frame(let width, let height, let fillWidth, let fillHeight, let alignment, let child):
            return .frame(width: width, height: height, fillWidth: fillWidth, fillHeight: fillHeight, alignment: alignment, child: child.applyingStyle(style))
        case .lineLimit(let limit, let child):
            return .lineLimit(limit, child: child.applyingStyle(style))
        case .scroll(let offset, let height, let bar, let width, let child):
            return .scroll(offset: offset, height: height, bar: bar, width: width, child: child.applyingStyle(style))
        case .hscroll(let offset, let extent, let bar, let child):
            return .hscroll(offset: offset, extent: extent, bar: bar, child: child.applyingStyle(style))
        case .border(let s, let fill, let box, let child):
            return .border(style: s.inheriting(style), fill: fill, box: box, child: child.applyingStyle(style))
        case .shadow(let s, let child):
            // The shadow cell keeps its own style; only the content inherits.
            return .shadow(style: s, child: child.applyingStyle(style))
        case .viewThatFits(let cw, let ch, let candidates):
            return .viewThatFits(checkWidth: cw, checkHeight: ch, candidates: candidates.map { $0.applyingStyle(style) })
        case .control(let id, let child):
            return .control(id: id, child: child.applyingStyle(style))
        }
    }

    /// Wraps the node as the clickable footprint of control `id` — unless
    /// control registration is currently suppressed (the inert layers beneath
    /// the active navigation layer must not receive pointer events, exactly
    /// as they receive no keys).
    func asControl(id: String) -> RenderNode {
        guard !FocusCoordinator.shared.isRegistrationSuppressed else { return self }
        return .control(id: id, child: self)
    }
}
