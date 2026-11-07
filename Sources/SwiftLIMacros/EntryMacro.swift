//
//  EntryMacro.swift
//  SwiftLIMacros
//
//  Created by Keisuke Chinone on 2026/11/07.
//

import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - @Entry

/// Expands `@Entry var x: T = initial` inside an `EnvironmentValues`
/// extension the way SwiftUI's `Entry()` macro does: the property becomes
/// computed over a private ``EnvironmentKey`` peer whose default is the
/// declaration's initial value.
///
/// ```swift
/// extension EnvironmentValues {
///     @Entry var verbosity: Int = 0
/// }
/// ```
///
/// becomes
///
/// ```swift
/// extension EnvironmentValues {
///     var verbosity: Int {
///         get { self[__Key_verbosity.self] }
///         set { self[__Key_verbosity.self] = newValue }
///     }
///     private struct __Key_verbosity: SwiftLI.EnvironmentKey {
///         typealias Value = Int
///         static var defaultValue: Value { 0 }
///     }
/// }
/// ```
///
/// The default is a computed `static var`, so it is evaluated on each read of
/// an un-injected value — exactly as a hand-written key with
/// `static var defaultValue: Value { ... }` behaves. An optional property may
/// omit the initial value; its default is then `nil`.
public struct EntryMacro: AccessorMacro, PeerMacro {

    // MARK: Accessors

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        let entry = try EntryProperty(declaration)
        return [
            "get { self[\(raw: entry.keyName).self] }",
            "set { self[\(raw: entry.keyName).self] = newValue }",
        ]
    }

    // MARK: Peers

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let entry = try EntryProperty(declaration)
        return [
            """
            private struct \(raw: entry.keyName): SwiftLI.EnvironmentKey {
                typealias Value = \(entry.type.trimmed)
                static var defaultValue: Value { \(entry.defaultValue.trimmed) }
            }
            """
        ]
    }
}

// MARK: - Declaration analysis

/// The parts of an `@Entry` declaration the expansions need.
struct EntryProperty {
    let name: String
    let type: TypeSyntax
    let defaultValue: ExprSyntax

    static let keyPrefix = "__Key_"

    var keyName: String { Self.keyPrefix + name }

    init(_ declaration: some DeclSyntaxProtocol) throws {
        guard let variable = declaration.as(VariableDeclSyntax.self) else {
            throw EntryMacroError.notAVariable
        }
        guard variable.bindingSpecifier.tokenKind == .keyword(.var) else {
            throw EntryMacroError.notVar
        }
        guard variable.bindings.count == 1, let binding = variable.bindings.first else {
            throw EntryMacroError.multipleBindings
        }
        guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
            throw EntryMacroError.notAnIdentifier
        }
        if let accessors = binding.accessorBlock {
            switch accessors.accessors {
            case .getter:
                throw EntryMacroError.computedProperty
            case .accessors(let list) where list.contains(where: { $0.accessorSpecifier.tokenKind == .keyword(.get) || $0.accessorSpecifier.tokenKind == .keyword(.set) }):
                throw EntryMacroError.computedProperty
            default:
                break
            }
        }
        // The key's `Value` and the computed property both need the type
        // spelled out: once the property gains accessors its initializer no
        // longer takes part in type inference.
        guard let type = binding.typeAnnotation?.type else {
            throw EntryMacroError.missingType
        }

        name = identifier.identifier.text
        self.type = type

        if let value = binding.initializer?.value {
            defaultValue = value
        } else if Self.isOptional(type) {
            defaultValue = "nil"
        } else {
            throw EntryMacroError.missingDefaultValue
        }
    }

    private static func isOptional(_ type: TypeSyntax) -> Bool {
        if type.is(OptionalTypeSyntax.self) || type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self) { return true }
        if let identifier = type.as(IdentifierTypeSyntax.self), identifier.name.text == "Optional" { return true }
        if let member = type.as(MemberTypeSyntax.self), member.name.text == "Optional" { return true }
        return false
    }
}

// MARK: - Diagnostics

enum EntryMacroError: Error, CustomStringConvertible {
    case notAVariable
    case notVar
    case multipleBindings
    case notAnIdentifier
    case computedProperty
    case missingType
    case missingDefaultValue

    var description: String {
        switch self {
        case .notAVariable:
            return "'@Entry' can only be applied to a property"
        case .notVar:
            return "'@Entry' must be applied to a 'var', not a 'let'"
        case .multipleBindings:
            return "'@Entry' can only be applied to a single property declaration"
        case .notAnIdentifier:
            return "'@Entry' requires a simple property name"
        case .computedProperty:
            return "'@Entry' cannot be applied to a computed property"
        case .missingType:
            return "'@Entry' requires an explicit type annotation"
        case .missingDefaultValue:
            return "'@Entry' requires a default value (or an optional type)"
        }
    }
}
