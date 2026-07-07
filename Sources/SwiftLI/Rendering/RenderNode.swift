//
//  RenderNode.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/06.
//

/// The intermediate representation (IR) of a view tree.
///
/// Every ``View`` lowers itself into a `RenderNode` tree via `makeNode()`.
/// The tree is a pure value: it can be measured, laid out, compared with the
/// tree of a previous render, and finally drawn — all without touching
/// stdout. This decoupling is what allows SwiftLI to understand *which part*
/// of the output changed and rewrite only that part.
///
/// The rendering pipeline is:
///
/// ```
/// View ──makeNode()──▶ RenderNode ──NodeLayout──▶ Frame ──FrameDiff──▶ stdout
/// ```
public indirect enum RenderNode: Equatable, Sendable {
    /// Renders nothing and occupies no space.
    case empty

    /// Styled text runs. Each element of `contents` is emitted with `header`
    /// prepended and an ANSI reset appended, joined on the same logical line
    /// (unless a content string itself contains newlines).
    case text(header: String, contents: [String])

    /// Flexible blank space: horizontal (columns) inside an ``HStack``,
    /// vertical (blank rows) everywhere else.
    case spacer(header: String, count: Int)

    /// A separator: a vertical line inside an ``HStack``, a horizontal line
    /// everywhere else.
    ///
    /// When `fillsWidth` is `true` the horizontal line spans the full terminal
    /// width, recomputed at layout time. Otherwise the length is resolved by
    /// the enclosing stack, falling back to `count` when there is no stack to
    /// span.
    case divider(header: String, character: Character, verticalCharacter: Character, count: Int, fillsWidth: Bool)

    /// A transparent container. Children are flattened into the enclosing
    /// stack; at the top level they stack vertically with no spacing.
    case group(children: [RenderNode])

    /// Children laid out side-by-side, aligned to the top or bottom row.
    case hstack(alignment: VerticalAlignment, spacing: Int, children: [RenderNode])

    /// Children laid out top-to-bottom, aligned to the leading or trailing edge.
    case vstack(alignment: HorizontalAlignment, spacing: Int, children: [RenderNode])

    /// Blank space around a child.
    case padding(edges: Edge.Set, length: Int, child: RenderNode)

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
    /// `offset ..< offset + height` are drawn. `thumb`/`track` are pre-styled
    /// single-glyph strings for the scrollbar drawn to the right of the content;
    /// both `nil` hides the scrollbar.
    case scroll(offset: Int, height: Int, thumb: String?, track: String?, child: RenderNode)

    /// A raw ANSI escape sequence emitted before the frame's grid content
    /// (used by ``Clear``). Occupies no cells.
    case raw(String)

    /// Returns a copy of the tree with `header` prepended to every styled leaf.
    ///
    /// This is how container styles (modifiers applied to ``Group``,
    /// ``HStack``, or ``VStack``) cascade down to the text, spacer, and
    /// divider leaves.
    public func applyingHeader(_ header: String) -> RenderNode {
        guard !header.isEmpty else { return self }
        switch self {
        case .empty, .raw:
            return self
        case .text(let h, let contents):
            return .text(header: header + h, contents: contents)
        case .spacer(let h, let count):
            return .spacer(header: header + h, count: count)
        case .divider(let h, let character, let verticalCharacter, let count, let fillsWidth):
            return .divider(header: header + h, character: character, verticalCharacter: verticalCharacter, count: count, fillsWidth: fillsWidth)
        case .group(let children):
            return .group(children: children.map { $0.applyingHeader(header) })
        case .hstack(let alignment, let spacing, let children):
            return .hstack(alignment: alignment, spacing: spacing, children: children.map { $0.applyingHeader(header) })
        case .vstack(let alignment, let spacing, let children):
            return .vstack(alignment: alignment, spacing: spacing, children: children.map { $0.applyingHeader(header) })
        case .padding(let edges, let length, let child):
            return .padding(edges: edges, length: length, child: child.applyingHeader(header))
        case .frame(let width, let height, let fillWidth, let fillHeight, let alignment, let child):
            return .frame(width: width, height: height, fillWidth: fillWidth, fillHeight: fillHeight, alignment: alignment, child: child.applyingHeader(header))
        case .lineLimit(let limit, let child):
            return .lineLimit(limit, child: child.applyingHeader(header))
        case .scroll(let offset, let height, let thumb, let track, let child):
            return .scroll(offset: offset, height: height, thumb: thumb, track: track, child: child.applyingHeader(header))
        }
    }
}
