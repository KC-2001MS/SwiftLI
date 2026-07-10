//
//  Weight.swift
//
//  Created by Keisuke Chinone on 2024/05/28.
//


/// The typographic weight of a view's rendered text.
///
/// Pass a `Weight` to ``View/fontWeight(_:)`` to control the boldness of a
/// view's output.
///
/// ```swift
/// Text("Normal")  .fontWeight(.default).render()
/// Text("Bold")    .fontWeight(.bold).render()
/// Text("Thin")    .fontWeight(.thin).render()
/// ```
///
/// > Note: Terminal support for thin (faint) weight varies. Most modern
/// > terminal emulators render `.thin` as a dimmed or faint variant.
public enum Weight: String, CaseIterable, Sendable {

    /// The terminal's default weight — no weight attribute is applied.
    case `default` = "0"

    /// Bold weight (ANSI SGR code 1).
    case bold = "1"

    /// Thin / faint weight (ANSI SGR code 2).
    case thin = "2"
}
