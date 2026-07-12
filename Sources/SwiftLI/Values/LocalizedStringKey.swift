//
//  LocalizedStringKey.swift
//  SwiftLI
//  
//  Created by Keisuke Chinone on 8/28/24.
//

import Foundation

/// The key used to look up an entry in a strings file or strings dictionary file.
@frozen
public struct LocalizedStringKey: Equatable {
    var localizationValue: String.LocalizationValue
    
    /// Creates a localized string key from the given string value.
    /// - Parameter value: The string to use as a localization key.
    public init(_ value: String) {
        self.localizationValue = String.LocalizationValue(value)
    }
}

extension LocalizedStringKey: ExpressibleByExtendedGraphemeClusterLiteral {
    /// Creates a localized string key from the given extended grapheme cluster literal.
    /// - Parameter value: The extended grapheme cluster literal to use as a localization key.
    public init(extendedGraphemeClusterLiteral value: String) {
        self.localizationValue = String.LocalizationValue(value)
    }
}

extension LocalizedStringKey: ExpressibleByStringInterpolation, ExpressibleByStringLiteral {
    /// Creates a localized string key from the given string literal.
    /// - Parameter value: The string literal to use as a localization key.
    public init(stringLiteral value: String) {
        self = .init(value)
    }
}

extension LocalizedStringKey: ExpressibleByUnicodeScalarLiteral {
    /// Creates a localized string key from the given Unicode scalar literal.
    /// - Parameter value: The Unicode scalar literal to use as a localization key.
    public init(unicodeScalarLiteral value: UnicodeScalar) {
        self.localizationValue = String.LocalizationValue(String(value))
    }
}
