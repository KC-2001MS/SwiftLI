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
                .newLine()
            
            Group {
                Text("Text.forgroundColor(_ color: Color)")
                    .forgroundColor(.red)
                    .newLine()
                
                Text("Text.backgroundColor(_ color: Color)")
                    .background(.red)
                    .newLine()
                
                Text("Text.bold()")
                    .bold()
                    .newLine()
                
                Text("Text.bold(_ isActive: Bool)")
                    .bold(false)
                
                Break(1)
                
                Text("Text.fontWeight(_ weight: Weight)")
                    .fontWeight(.thin)
                    .newLine()
                
                Text("Text.italic()")
                    .italic()
                    .newLine()
                
                Text("Text.italic(_ isActive: Bool)")
                    .italic(false)
                    .newLine()
                
                Text("Text.underline()")
                    .underline()
                    .newLine()
                
                Text("Text.underline(_ isActive: Bool)")
                    .underline(false)
                    .newLine()
                
                Text("Text.blink(_ style: BlinkStyle)")
                    .blink(.default)
                    .newLine()
                
                Text("Text.hidden()")
                    .hidden()
                    .newLine()
                
                Text("Text.hidden(_ isActive: Bool)")
                    .hidden(false)
                    .newLine()
                
                Text("Text.strikethrough()")
                    .strikethrough()
                    .newLine()
                
                Text("Text.strikethrough(_ isActive: Bool)")
                    .strikethrough(false)
                    .newLine()
            }
        }
        
        group.render()
    }
}
