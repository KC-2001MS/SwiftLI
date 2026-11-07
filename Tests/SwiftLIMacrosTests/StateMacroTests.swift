//
//  StateMacroTests.swift
//  SwiftLIMacrosTests
//
//  Created by Keisuke Chinone on 2026/11/06.
//

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing
import SwiftLIMacros

private let testMacros: [String: Macro.Type] = [
    "State": StateMacro.self,
    "_StateStorageAccessor": StateStorageAccessorMacro.self,
    "_StateProjectedValue": StateProjectedValueMacro.self,
]

// The expanded sources below omit the declarations' initial values: the
// test support prints a property that gained accessors without its
// initializer, exactly as the compiler treats it once the accessors exist.
@Suite("@State macro expansion")
struct StateMacroTests {

    @Test("A private state with an inferred type expands to lazy storage and get/set accessors")
    func privateInferred() {
        assertMacroExpansion(
            """
            struct Counter {
                @State private var count = 0
            }
            """,
            expandedSource: """
            struct Counter {
                private var count {
                    get {
                        count__storage.wrappedValue
                    }
                    nonmutating set {
                        count__storage.wrappedValue = newValue
                    }
                }

                private var count__storage = SwiftLI.State._makeStorage(named: "count") {
                    0
                }

                @SwiftLI._StateStorageAccessor private var _count = SwiftLI.State._makeStorage(named: "count") {
                    0
                }

                @SwiftLI._StateProjectedValue private var $count = SwiftLI.State._makeStorage(named: "count") {
                    0
                } .projectedValue
            }
            """,
            macros: testMacros
        )
    }

    @Test("A non-private state with a type annotation also gets an init accessor")
    func internalTyped() {
        assertMacroExpansion(
            """
            struct Form {
                @State var name: String = ""
            }
            """,
            expandedSource: """
            struct Form {
                var name: String {
                    @storageRestrictions(initializes: name__storage)
                    init(initialValue) {
                        name__storage = SwiftLI.State._makeStorage(named: "name", initialValue: initialValue)
                    }
                    get {
                        name__storage.wrappedValue
                    }
                    nonmutating set {
                        name__storage.wrappedValue = newValue
                    }
                }

                private var name__storage = SwiftLI.State<String>._makeStorage(named: "name") {
                    ""
                }

                @SwiftLI._StateStorageAccessor var _name = SwiftLI.State<String>._makeStorage(named: "name") {
                    ""
                }

                @SwiftLI._StateProjectedValue var $name = SwiftLI.State<String>._makeStorage(named: "name") {
                    ""
                } .projectedValue
            }
            """,
            macros: testMacros
        )
    }

    @Test("An optional state without an initial value starts as nil")
    func optionalWithoutInitialValue() {
        assertMacroExpansion(
            """
            struct Picker {
                @State var selection: Int?
            }
            """,
            expandedSource: """
            struct Picker {
                var selection: Int? {
                    get {
                        selection__storage.wrappedValue
                    }
                    nonmutating set {
                        selection__storage.wrappedValue = newValue
                    }
                }

                private var selection__storage = SwiftLI.State<Int?>._makeStorage(named: "selection") {
                    nil
                }

                @SwiftLI._StateStorageAccessor var _selection = SwiftLI.State<Int?>._makeStorage(named: "selection") {
                    nil
                }

                @SwiftLI._StateProjectedValue var $selection = SwiftLI.State<Int?>._makeStorage(named: "selection") {
                    nil
                } .projectedValue
            }
            """,
            macros: testMacros
        )
    }

    @Test("The attribute can carry the initial value")
    func attributeInitialValue() {
        assertMacroExpansion(
            """
            struct Slider {
                @State(initialValue: 0.5) private var value: Double
            }
            """,
            expandedSource: """
            struct Slider {
                private var value: Double {
                    get {
                        value__storage.wrappedValue
                    }
                    nonmutating set {
                        value__storage.wrappedValue = newValue
                    }
                }

                private var value__storage = SwiftLI.State<Double>._makeStorage(named: "value") {
                    0.5
                }

                @SwiftLI._StateStorageAccessor private var _value = SwiftLI.State<Double>._makeStorage(named: "value") {
                    0.5
                }

                @SwiftLI._StateProjectedValue private var $value = SwiftLI.State<Double>._makeStorage(named: "value") {
                    0.5
                } .projectedValue
            }
            """,
            macros: testMacros
        )
    }

    @Test("The helper accessor macros produce the peers' bodies")
    func helperAccessors() {
        assertMacroExpansion(
            """
            @_StateStorageAccessor var _count = 1
            @_StateProjectedValue var $count = 2
            """,
            expandedSource: """
            var _count {
                get {
                    count__storage
                }
                set {
                    count__storage = newValue
                }
            }
            var $count {
                get {
                    count__storage.projectedValue
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("A state without an initial value or an optional type is rejected")
    func missingInitialValue() {
        assertMacroExpansion(
            """
            struct Broken {
                @State var count: Int
            }
            """,
            expandedSource: """
            struct Broken {
                var count: Int
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "'@State' requires an initial value (or an optional type)", line: 2, column: 5),
                DiagnosticSpec(message: "'@State' requires an initial value (or an optional type)", line: 2, column: 5),
            ],
            macros: testMacros
        )
    }

    @Test("A let is rejected")
    func letRejected() {
        assertMacroExpansion(
            """
            struct Broken {
                @State let count = 0
            }
            """,
            expandedSource: """
            struct Broken {
                let count = 0
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "'@State' must be applied to a 'var', not a 'let'", line: 2, column: 5),
                DiagnosticSpec(message: "'@State' must be applied to a 'var', not a 'let'", line: 2, column: 5),
            ],
            macros: testMacros
        )
    }
}
