//
//  StateMacro.swift
//  SwiftLIMacros
//
//  Created by Keisuke Chinone on 2026/11/06.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - @State

/// Expands `@State var x: T = initial` the way SwiftUI's `State()` macro does
/// since Xcode 27: the property becomes computed over a lazily resolved
/// storage peer, and `_x` / `$x` peers keep the property-wrapper surface.
///
/// ```swift
/// @State private var count = 0
/// ```
///
/// becomes
///
/// ```swift
/// private var count__storage = SwiftLI.State._makeStorage(named: "count") { 0 }
/// @SwiftLI._StateStorageAccessor private var _count = SwiftLI.State._makeStorage(named: "count") { 0 }
/// @SwiftLI._StateProjectedValue private var $count = SwiftLI.State._makeStorage(named: "count") { 0 }.projectedValue
/// var count: Int {
///     get { count__storage.wrappedValue }
///     nonmutating set { count__storage.wrappedValue = newValue }
/// }
/// ```
///
/// What the expansion buys over the property wrapper:
///
/// - **The initial value is evaluated lazily.** The wrapper evaluated it every
///   time the enclosing struct was initialised — once per frame for a view
///   inside a re-evaluated body. The macro hands the runtime a closure, run
///   only when the state is first read.
/// - **The storage knows the property's name.** Together with the view's
///   position in the render tree this gives each `@State` a stable identity,
///   so the rendering engine can hand a child view the *same* storage on
///   every frame — the view's state persists exactly as in SwiftUI, instead
///   of resetting whenever the parent's body runs.
///
/// The storage peer is `x__storage` rather than SwiftUI's `__x`: ArgumentParser
/// derives a command's decoding keys by stripping one leading underscore from
/// each stored property's name, and `__x` would no longer round-trip. A
/// trailing suffix keeps `@State` usable inside commands.
///
/// `_x` and `$x` are declared with the same `_makeStorage(...)` expression as
/// their initial value even though an accessor macro turns them into computed
/// properties: when the declaration carries no type annotation the expression
/// is what tells the compiler their types. (SwiftUI's expansion does the same.)
///
/// For a property that is not `private`, `x` also gets an `init(initialValue)`
/// accessor so the memberwise initializer still accepts `x:` as the wrapper's
/// did.
public struct StateMacro: AccessorMacro, PeerMacro {

    // MARK: Accessors

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        let property = try StateProperty(declaration, attribute: node, in: context)
        var accessors: [AccessorDeclSyntax] = []
        if property.providesInitAccessor {
            accessors.append(
                """
                @storageRestrictions(initializes: \(raw: property.storageName))
                init(initialValue) {
                    \(raw: property.storageName) = SwiftLI.State._makeStorage(named: \(literal: property.name), initialValue: initialValue)
                }
                """
            )
        }
        accessors.append("get { \(raw: property.storageName).wrappedValue }")
        accessors.append("nonmutating set { \(raw: property.storageName).wrappedValue = newValue }")
        return accessors
    }

    // MARK: Peers

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let property = try StateProperty(declaration, attribute: node, in: context)
        let storage = property.storageExpression
        let access = property.accessModifiers
        return [
            "private var \(raw: property.storageName) = \(storage)",
            "@SwiftLI._StateStorageAccessor \(raw: access)var _\(raw: property.name) = \(storage)",
            "@SwiftLI._StateProjectedValue \(raw: access)var $\(raw: property.name) = \(storage).projectedValue",
        ]
    }
}

// MARK: - Helper accessor macros

/// Gives the `_x` peer its body: it reads and writes the storage peer.
public struct StateStorageAccessorMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        let storage = try StateProperty.storageName(forPeer: declaration, droppingPrefix: "_")
        return [
            "get { \(raw: storage) }",
            "set { \(raw: storage) = newValue }",
        ]
    }
}

/// Gives the `$x` peer its body: the storage's projected ``Binding``.
public struct StateProjectedValueMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        let storage = try StateProperty.storageName(forPeer: declaration, droppingPrefix: "$")
        return ["get { \(raw: storage).projectedValue }"]
    }
}

// MARK: - Declaration analysis

/// The parts of a `@State` declaration the expansions need.
struct StateProperty {
    let name: String
    /// The declared type, when the property has an annotation.
    let type: TypeSyntax?
    /// The initial value: the declaration's initializer, the attribute's
    /// `initialValue:` / `wrappedValue:` argument, or `nil` for an optional
    /// type declared without either.
    let initialValue: ExprSyntax
    let isPrivate: Bool
    let accessModifiers: String
    let hasExplicitInitialValue: Bool

    static let storageSuffix = "__storage"

    var storageName: String { name + Self.storageSuffix }

    /// A non-private state keeps its place in the memberwise initializer, so
    /// `x` takes the value through an `init` accessor (as the wrapper's
    /// `wrappedValue` did). A private one is excluded from it anyway, which is
    /// what lets its initial value stay lazy.
    var providesInitAccessor: Bool { !isPrivate && hasExplicitInitialValue }

    /// `SwiftLI.State<T>._makeStorage(named: "x") { initial }` — the type
    /// argument is spelled out only when the declaration has one, otherwise
    /// the closure's result type infers it.
    var storageExpression: ExprSyntax {
        let typeArguments = type.map { "<\($0.trimmedDescription)>" } ?? ""
        return "SwiftLI.State\(raw: typeArguments)._makeStorage(named: \(literal: name)) { \(initialValue.trimmed) }"
    }

    init(_ declaration: some DeclSyntaxProtocol, attribute: AttributeSyntax, in context: some MacroExpansionContext) throws {
        guard let variable = declaration.as(VariableDeclSyntax.self) else {
            throw StateMacroError.notAVariable
        }
        guard variable.bindingSpecifier.tokenKind == .keyword(.var) else {
            throw StateMacroError.notVar
        }
        guard variable.bindings.count == 1, let binding = variable.bindings.first else {
            throw StateMacroError.multipleBindings
        }
        guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
            throw StateMacroError.notAnIdentifier
        }
        if let accessors = binding.accessorBlock {
            switch accessors.accessors {
            case .getter:
                throw StateMacroError.computedProperty
            case .accessors(let list) where list.contains(where: { $0.accessorSpecifier.tokenKind == .keyword(.get) || $0.accessorSpecifier.tokenKind == .keyword(.set) }):
                throw StateMacroError.computedProperty
            default:
                break
            }
        }

        name = identifier.identifier.text
        type = binding.typeAnnotation?.type

        // `@State(initialValue: x)` / `@State(wrappedValue: x)` supply the
        // value in the attribute instead of the declaration.
        var attributeValue: ExprSyntax?
        if case .argumentList(let arguments)? = attribute.arguments {
            for argument in arguments where argument.label?.text == "initialValue" || argument.label?.text == "wrappedValue" {
                attributeValue = argument.expression
            }
        }

        if let value = binding.initializer?.value {
            guard attributeValue == nil else { throw StateMacroError.doubleInitialValue }
            initialValue = value
            hasExplicitInitialValue = true
        } else if let attributeValue {
            initialValue = attributeValue
            hasExplicitInitialValue = true
        } else if let type, Self.isOptional(type) {
            initialValue = "nil"
            hasExplicitInitialValue = false
        } else {
            throw StateMacroError.missingInitialValue
        }

        var isPrivate = false
        var access: [String] = []
        for modifier in variable.modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.private), .keyword(.fileprivate):
                // `private(set)` restricts the setter only; the getter's level
                // is what decides whether the memberwise initializer sees it.
                if modifier.detail == nil { isPrivate = true }
                access.append(modifier.trimmedDescription)
            case .keyword(.public), .keyword(.internal), .keyword(.package), .keyword(.open):
                access.append(modifier.trimmedDescription)
            default:
                break
            }
        }
        self.isPrivate = isPrivate
        accessModifiers = access.isEmpty ? "" : access.joined(separator: " ") + " "
    }

    private static func isOptional(_ type: TypeSyntax) -> Bool {
        if type.is(OptionalTypeSyntax.self) { return true }
        if let identifier = type.as(IdentifierTypeSyntax.self), identifier.name.text == "Optional" { return true }
        if let member = type.as(MemberTypeSyntax.self), member.name.text == "Optional" { return true }
        return false
    }

    /// The storage peer a generated `_x` / `$x` declaration refers to.
    static func storageName(forPeer declaration: some DeclSyntaxProtocol, droppingPrefix prefix: Character) throws -> String {
        guard
            let variable = declaration.as(VariableDeclSyntax.self),
            let identifier = variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
            identifier.first == prefix
        else {
            throw StateMacroError.helperMisuse
        }
        return String(identifier.dropFirst()) + storageSuffix
    }
}

// MARK: - Diagnostics

enum StateMacroError: Error, CustomStringConvertible {
    case notAVariable
    case notVar
    case multipleBindings
    case notAnIdentifier
    case computedProperty
    case missingInitialValue
    case doubleInitialValue
    case helperMisuse

    var description: String {
        switch self {
        case .notAVariable:
            return "'@State' can only be applied to a stored property"
        case .notVar:
            return "'@State' must be applied to a 'var', not a 'let'"
        case .multipleBindings:
            return "'@State' can only be applied to a single property declaration"
        case .notAnIdentifier:
            return "'@State' requires a simple property name"
        case .computedProperty:
            return "'@State' cannot be applied to a computed property"
        case .missingInitialValue:
            return "'@State' requires an initial value (or an optional type)"
        case .doubleInitialValue:
            return "'@State' received an initial value both in the attribute and in the declaration"
        case .helperMisuse:
            return "this macro is an implementation detail of '@State' and cannot be applied directly"
        }
    }
}
