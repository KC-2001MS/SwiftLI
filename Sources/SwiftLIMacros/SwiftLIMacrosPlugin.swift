//
//  SwiftLIMacrosPlugin.swift
//  SwiftLIMacros
//
//  Created by Keisuke Chinone on 2026/11/06.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

/// The compiler plugin that hosts SwiftLI's macros.
///
/// `@State` is expanded by ``StateMacro``; the two helper accessor macros
/// give the generated `_x` and `$x` peers their bodies (see `StateMacro.swift`
/// for why they exist). `@Entry` is expanded by ``EntryMacro``.
@main
struct SwiftLIMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StateMacro.self,
        StateStorageAccessorMacro.self,
        StateProjectedValueMacro.self,
        EntryMacro.self,
    ]
}
