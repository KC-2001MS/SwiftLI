//
//  MouseEvent.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/12.
//

/// A single decoded pointing-device event.
///
/// Terminals report mouse activity as escape sequences on stdin, in the same
/// byte stream as keystrokes. ``KeyDecoder`` parses them (SGR `CSI < b;x;y M/m`
/// reports, with the legacy X10 encoding as a fallback) and delivers them as
/// ``KeyEvent/mouse(_:)`` events, which the reactive runtime routes to the
/// control under the pointer.
///
/// Positions are 0-based terminal grid coordinates — the same space as
/// ``Point``: `(column: 0, row: 0)` is the top-left cell. Mouse reporting is
/// only enabled for full-screen sessions, where the frame's first line is the
/// terminal's first row, so an event's position addresses the rendered frame
/// directly.
public struct MouseEvent: Equatable, Sendable {

    /// A physical mouse button.
    public enum Button: Equatable, Sendable {
        /// The primary (left) mouse button.
        case left
        /// The middle mouse button (scroll-wheel click).
        case middle
        /// The secondary (right) mouse button.
        case right
    }

    /// What the pointing device did.
    public enum Kind: Equatable, Sendable {
        /// A button was pressed.
        case press(Button)
        /// A button was released.
        case release(Button)
        /// The pointer moved while a button was held.
        case drag(Button)
        /// The pointer moved with no button held (only reported in
        /// any-motion tracking modes; SwiftLI does not request them).
        case move
        /// The scroll wheel rolled up (away from the user).
        case scrollUp
        /// The scroll wheel rolled down (toward the user).
        case scrollDown
        /// The trackpad or horizontal scroll wheel swiped left.
        case scrollLeft
        /// The trackpad or horizontal scroll wheel swiped right.
        case scrollRight
    }

    /// What happened.
    public let kind: Kind
    /// Horizontal position, 0-based (0 = leftmost column).
    public let column: Int
    /// Vertical position, 0-based (0 = topmost row).
    public let row: Int

    /// Creates a mouse event with the given action and position.
    ///
    /// - Parameters:
    ///   - kind: The type of pointing-device action that occurred.
    ///   - column: The 0-based horizontal grid position of the pointer.
    ///   - row: The 0-based vertical grid position of the pointer.
    public init(kind: Kind, column: Int, row: Int) {
        self.kind = kind
        self.column = column
        self.row = row
    }
}
