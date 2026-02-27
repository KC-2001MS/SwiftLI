//
//  BlinkStyle.swift
//
//  Created by Keisuke Chinone on 2024/05/28.
//


/// The blinking behaviour applied to a view.
///
/// Pass a `BlinkStyle` to ``View/blink(_:)`` to make a view blink:
///
/// ```swift
/// Text("Alert!").blink(.default).render()
/// ```
///
/// > Note: The macOS built-in Terminal.app does not render blinking text.
/// > Blinking is supported by most third-party terminal emulators (iTerm2,
/// > Alacritty, kitty, etc.).
public enum BlinkStyle: String, CaseIterable, Sendable {

    /// No blinking — equivalent to calling ``View/blink(_:)`` with `.none`.
    case none = "0"

    /// Standard blinking (ANSI SGR code 5, approximately 0.5 Hz).
    case `default` = "5"
//    Removed because it does not work with macOS terminal app
//    case fast = "6"
}
