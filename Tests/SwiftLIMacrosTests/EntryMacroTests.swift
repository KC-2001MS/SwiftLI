//
//  EntryMacroTests.swift
//  SwiftLIMacrosTests
//
//  Created by Keisuke Chinone on 2026/11/07.
//

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing
import SwiftLIMacros

private let testMacros: [String: Macro.Type] = [
    "Entry": EntryMacro.self,
]

@Suite("@Entry macro expansion")
struct EntryMacroTests {

    @Test("An entry expands to subscript accessors and a private key holding the default")
    func basicEntry() {
        assertMacroExpansion(
            """
            extension EnvironmentValues {
                @Entry var verbosity: Int = 0
            }
            """,
            expandedSource: """
            extension EnvironmentValues {
                var verbosity: Int {
                    get {
                        self[__Key_verbosity.self]
                    }
                    set {
                        self[__Key_verbosity.self] = newValue
                    }
                }

                private struct __Key_verbosity: SwiftLI.EnvironmentKey {
                    typealias Value = Int
                    static var defaultValue: Value {
                        0
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("An optional entry without an initial value defaults to nil")
    func optionalEntry() {
        assertMacroExpansion(
            """
            extension EnvironmentValues {
                @Entry public var label: String?
            }
            """,
            expandedSource: """
            extension EnvironmentValues {
                public var label: String? {
                    get {
                        self[__Key_label.self]
                    }
                    set {
                        self[__Key_label.self] = newValue
                    }
                }

                private struct __Key_label: SwiftLI.EnvironmentKey {
                    typealias Value = String?
                    static var defaultValue: Value {
                        nil
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("A missing type annotation is diagnosed")
    func missingType() {
        assertMacroExpansion(
            """
            extension EnvironmentValues {
                @Entry var verbosity = 0
            }
            """,
            expandedSource: """
            extension EnvironmentValues {
                var verbosity = 0
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "'@Entry' requires an explicit type annotation", line: 2, column: 5),
                DiagnosticSpec(message: "'@Entry' requires an explicit type annotation", line: 2, column: 5),
            ],
            macros: testMacros
        )
    }

    @Test("A non-optional entry without a default is diagnosed")
    func missingDefault() {
        assertMacroExpansion(
            """
            extension EnvironmentValues {
                @Entry var verbosity: Int
            }
            """,
            expandedSource: """
            extension EnvironmentValues {
                var verbosity: Int
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "'@Entry' requires a default value (or an optional type)", line: 2, column: 5),
                DiagnosticSpec(message: "'@Entry' requires a default value (or an optional type)", line: 2, column: 5),
            ],
            macros: testMacros
        )
    }
}
