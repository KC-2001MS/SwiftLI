//
//  ColorScheme.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/10.
//

/// The colour appearance of the terminal, mirroring SwiftUI's `ColorScheme`.
///
/// Read it from the environment to adapt colours to the terminal's background:
///
/// ```swift
/// @Environment(\.colorScheme) var colorScheme
///
/// var body: some View {
///     Text("Hello").forgroundColor(colorScheme == .dark ? .white : .black)
/// }
/// ```
public enum ColorScheme: Equatable, Sendable {
    /// A light terminal background.
    case light
    /// A dark terminal background.
    case dark
}
