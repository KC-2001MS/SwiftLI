//
//  AttributedText.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/11/08.
//

import Foundation

// MARK: - Attribute scope

extension AttributeScopes {
    /// The attributes ``Text/init(_:)`` reads from an `AttributedString`,
    /// mirroring the role of SwiftUI's `SwiftUIAttributes` scope.
    ///
    /// Set them through dynamic member lookup on a run or a whole string:
    ///
    /// ```swift
    /// var summary = AttributedString("Build passed in 42s")
    /// if let range = summary.range(of: "passed") {
    ///     summary[range].foregroundColor = .green
    ///     summary[range].fontWeight = .bold
    /// }
    /// Text(summary)
    /// ```
    ///
    /// Foundation's own attributes are honoured too: `inlinePresentationIntent`
    /// (`.stronglyEmphasized` → bold, `.emphasized` → italic,
    /// `.strikethrough`) and `link` (an OSC 8 hyperlink).
    public struct SwiftLIAttributes: AttributeScope {
        /// The run's text colour.
        public let foregroundColor: ForegroundColorAttribute
        /// The run's background colour.
        public let backgroundColor: BackgroundColorAttribute
        /// The run's weight.
        public let fontWeight: FontWeightAttribute
        /// Whether the run is underlined.
        public let underline: UnderlineAttribute
        /// Whether the run is italic.
        public let italic: ItalicAttribute
        /// Whether the run is struck through.
        public let strikethrough: StrikethroughAttribute
        /// Foundation's attributes, so `.link` and `.inlinePresentationIntent`
        /// resolve through this scope as well.
        public let foundation: FoundationAttributes

        /// The key of the ``foregroundColor`` attribute.
        public enum ForegroundColorAttribute: AttributedStringKey {
            public typealias Value = Color
            public static let name = "SwiftLI.ForegroundColor"
        }
        /// The key of the ``backgroundColor`` attribute.
        public enum BackgroundColorAttribute: AttributedStringKey {
            public typealias Value = Color
            public static let name = "SwiftLI.BackgroundColor"
        }
        /// The key of the ``fontWeight`` attribute.
        public enum FontWeightAttribute: AttributedStringKey {
            public typealias Value = Weight
            public static let name = "SwiftLI.FontWeight"
        }
        /// The key of the ``underline`` attribute.
        public enum UnderlineAttribute: AttributedStringKey {
            public typealias Value = Bool
            public static let name = "SwiftLI.Underline"
        }
        /// The key of the ``italic`` attribute.
        public enum ItalicAttribute: AttributedStringKey {
            public typealias Value = Bool
            public static let name = "SwiftLI.Italic"
        }
        /// The key of the ``strikethrough`` attribute.
        public enum StrikethroughAttribute: AttributedStringKey {
            public typealias Value = Bool
            public static let name = "SwiftLI.Strikethrough"
        }
    }

    /// The SwiftLI attribute scope, for `\.swiftLI.foregroundColor` key paths.
    public var swiftLI: SwiftLIAttributes.Type { SwiftLIAttributes.self }
}

extension AttributeDynamicLookup {
    /// Resolves `run.foregroundColor`, `string.fontWeight`, … through the
    /// SwiftLI scope.
    public subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.SwiftLIAttributes, T>) -> T {
        self[T.self]
    }
}

// MARK: - Text from an AttributedString

/// One uniformly styled piece of a multi-style ``Text``.
struct TextRun: Equatable, Sendable {
    let style: TextStyle
    let text: String
}

extension TextRun {
    /// The style an attributed run carries.
    init(_ run: AttributedString.Runs.Run, in string: AttributedString) {
        var style = TextStyle()
        style.foreground = run.foregroundColor
        style.background = run.backgroundColor
        style.weight = run.fontWeight
        style.isUnderlined = run.underline ?? false
        style.isItalic = run.italic ?? false
        style.isStrikethrough = run.strikethrough ?? false
        if let intent = run.inlinePresentationIntent {
            if intent.contains(.stronglyEmphasized) { style.weight = style.weight ?? .bold }
            if intent.contains(.emphasized) { style.isItalic = true }
            if intent.contains(.strikethrough) { style.isStrikethrough = true }
        }
        if let link = run.link { style.link = link.absoluteString }
        self.init(style: style, text: String(string[run.range].characters))
    }
}
