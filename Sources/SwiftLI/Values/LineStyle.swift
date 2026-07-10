//
//  LineStyle.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/07/14.
//


/// The visual style of a ``Divider`` line.
///
/// Pass a `LineStyle` to ``Divider/lineStyle(_:)`` to select between a
/// single-line and a double-line divider:
///
/// ```swift
/// // Single-line divider (default)
/// Divider().lineStyle(.default)      // draws: --------
///
/// // Double-line divider
/// Divider().lineStyle(.double_line)  // draws: ========
/// ```
public enum LineStyle: CaseIterable, Sendable {

    /// A single-line divider using `-` (horizontal) and `|` (vertical).
    case `default`

    /// A double-line divider using `=` (horizontal) and `‖` (vertical).
    case double_line
}
