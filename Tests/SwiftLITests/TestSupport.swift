//
//  TestSupport.swift
//  SwiftLITests
//
//  Created by Keisuke Chinone on 2026/07/10.
//

#if swift(>=6.0)
import Testing
@_spi(RenderingInternals) @testable import SwiftLI
import Foundation

extension Tag {
    @Tag static var general: Self
    @Tag static var viewProtocol: Self
    @Tag static var text: Self
    @Tag static var group: Self
    @Tag static var hdivider: Self
    @Tag static var spacer: Self
    @Tag static var emotion: Self
    
    @Tag static var normalBehavior: Self
}

let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

let randomInt = Int.random(in: 5..<20)

let randomStrings = String((0..<randomInt).map{ _ in letters.randomElement()! })

let randomCharacter = randomStrings.randomElement()!

let allColors: [Color] = [
    .black,
    .red,
    .green,
    .yellow,
    .blue,
    .magenta,
    .cyan,
    .white,
    .eight_bit(202),
    .primary
]

// MARK: - Intermediate-representation diff testing

/// Removes SGR (colour/style) escape sequences — those ending in `m` — while
/// leaving cursor-movement sequences (`\e[2K`, `\e[1B`, …) intact so tests can
/// reason about both the visible text and the diff control codes.
func sgrStripped(_ s: String) -> String {
    s.replacingOccurrences(of: "\u{001B}\\[[0-9;?]*m", with: "", options: .regularExpression)
}

func occurrences(of needle: String, in haystack: String) -> Int {
    guard !needle.isEmpty else { return 0 }
    var count = 0
    var range = haystack.startIndex..<haystack.endIndex
    while let found = haystack.range(of: needle, range: range) {
        count += 1
        range = found.upperBound..<haystack.endIndex
    }
    return count
}

/// The ANSI "erase entire line" sequence emitted once per rewritten line.
let eraseLineCode = "\u{001B}[2K"

// MARK: - TextField input testing

/// Reference box so a `Binding`'s get/set closures stay `@Sendable`-safe.
final class StringBox: @unchecked Sendable {
    var value: String
    init(_ value: String) { self.value = value }
}

/// Boolean equivalent of ``StringBox`` for ``Toggle`` bindings.
final class BoolBox: @unchecked Sendable {
    var value: Bool
    init(_ value: Bool) { self.value = value }
}

/// Integer equivalent of ``StringBox`` for ``Picker`` bindings.
final class IntBox: @unchecked Sendable {
    var value: Int
    init(_ value: Int) { self.value = value }
}

/// Optional-integer box for ``List`` selection bindings.
final class OptionalIntBox: @unchecked Sendable {
    var value: Int?
    init(_ value: Int?) { self.value = value }
}

#endif
