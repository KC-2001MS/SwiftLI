//
//  Spacer.swift
//
//  Created by Keisuke Chinone on 2024/05/27.
//


/// A flexible space that expands along the major axis of its stack,
/// mirroring SwiftUI's `Spacer`.
///
/// Created with no arguments by default, with an optional `minLength` for
/// the minimum extent. The spacer **expands to take the maximum available
/// space along its stack's axis**, never shrinking below `minLength`:
///
/// - Inside an ``HStack`` it is horizontal, absorbing the row's leftover
///   columns — up to the proposed width, or the terminal width at the top
///   level — pushing the surrounding views to opposite edges.
/// - Inside a ``VStack`` (or ``Group`` / a top-level `body`) it is vertical,
///   absorbing the column's leftover rows — up to the terminal height at the
///   top level — pushing the surrounding views apart.
///
/// Several spacers in one stack share the leftover space evenly.
///
/// ```swift
/// // "Left" and "Right" pushed to the terminal's opposite edges:
/// HStack {
///     Text("Left")
///     Spacer()
///     Text("Right")
/// }
///
/// // "Footer" pushed to the bottom of the screen:
/// VStack {
///     Text("Content")
///     Spacer()
///     Text("Footer")
/// }
/// ```
public struct Spacer: View, Sendable, Equatable {
    let header: String

    /// The minimum number of cells the spacer occupies — space columns
    /// inside an ``HStack`` (where it then expands to the available width),
    /// blank rows everywhere else.
    let minLength: Int

    // MARK: - Initialisers

    /// Creates a spacer, matching SwiftUI's `Spacer(minLength:)`.
    ///
    /// - Parameter minLength: The minimum number of columns (inside
    ///   ``HStack``, before expansion) or blank rows (everywhere else) to
    ///   insert. `nil` — the default — means one cell.
    public init(minLength: Int? = nil) {
        self.header = ""
        self.minLength = minLength ?? 1
    }

    init(header: String, minLength: Int) {
        self.header = header
        self.minLength = minLength
    }

    // MARK: - View (vertical / default context)

    public var body: some View {
        EmptyView()
    }

    @_spi(RenderingInternals)
    public func addHeader(_ header: String) -> Self {
        return Spacer(header: header + self.header, minLength: self.minLength)
    }

    /// Lowers this spacer into a direction-adaptive ``RenderNode/spacer`` node.
    ///
    /// The layout engine interprets the node as horizontal blank columns
    /// inside an ``HStack`` and as vertical blank rows everywhere else.
    @_spi(RenderingInternals)
    public func makeNode() -> RenderNode {
        .spacer(header: header, minLength: minLength)
    }

    // MARK: - Modifiers

    /// Applies a background color to the spacer's cells.
    ///
    /// When used inside an ``HStack``, this colors the blank columns.
    /// Outside an ``HStack``, it colors the blank rows.
    ///
    /// - Parameter color: The background color to apply.
    public func background(_ color: Color) -> Spacer {
        return .init(header: "\(header)\u{001B}[4\(color.ansi)m", minLength: minLength)
    }
}
