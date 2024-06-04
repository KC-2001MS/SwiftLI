//
//  Text.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/27.
//


import ArgumentParser
import SwiftLI

struct TextCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "text",
        abstract: "Display of Text structure",
        discussion: """
        Command to check the display of Text structure
        """,
        version: "0.0.1",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )
    
    mutating func run() {
        let group = Group {
            Text("Break View")
                .background(Color.white)
                .forgroundColor(Color.blue)
                .bold()
            
            Break(1)
            
            Text("Text.forgroundColor(_ color: Color)")
                .forgroundColor(.red)
            
            Break(1)
            
            Text("Text.backgroundColor(_ color: Color)")
                .background(.red)
            
            Break(1)
            
            Text("Text.bold()")
                .bold()
            
            Break(1)
            
            Text("Text.bold(_ isActive: Bool)")
                .bold(false)
            
            Break(1)
            
            Text("Text.fontWeight(_ weight: Weight)")
                .fontWeight(.thin)
            
            Break(1)
            
            Text("Text.italic()")
                .italic()
            
            Break(1)
            
            Text("Text.italic(_ isActive: Bool)")
                .italic(false)
            
            Break(1)
            
            Text("Text.underline()")
                .underline()
            
            Break(1)
            
            Text("Text.underline(_ isActive: Bool)")
                .underline(false)
            
            Break(1)
            
            Text("Text.blink(_ style: BlinkStyle)")
                .blink(.default)
            
            Break(1)
            
            Text("Text.hidden()")
                .hidden()
            
            Break(1)
            
            Text("Text.hidden(_ isActive: Bool)")
                .hidden(false)
            
            Break(1)
            
            Text("Text.strikethrough()")
                .strikethrough()
            
            Break(1)
            
            Text("Text.strikethrough(_ isActive: Bool)")
                .strikethrough(false)
            
            Break(1)
            
            Text("\u{100205}")
            
            Break(1)
        }
        
        group.render()
    }
}
