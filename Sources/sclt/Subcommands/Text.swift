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
        version: "0.0.2",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )
    
    mutating func run() {
        let group = Group {
            Text("Text View")
                .background(Color.white)
                .forgroundColor(Color.blue)
                .bold()
                .newLine()
            
            Group {
                Group {
                    Text("Text.forgroundColor(_ color: Color)")
                        .forgroundColor(.red)
                    
                    Spacer()
                    
                    Text(".red")
                        .fontWeight(.thin)
                        .forgroundColor(.red)
                }
                .newLine()
                
                Group {
                    Text("Text.backgroundColor(_ color: Color)")
                        .background(.red)
                    
                    Spacer()
                    
                    Text(".red")
                        .fontWeight(.thin)
                        .forgroundColor(.red)
                }
                .newLine()
                
                Text("Text.bold()")
                    .bold()
                    .newLine()
                
                Group {
                    Text("Text.bold(_ isActive: Bool)")
                        .bold(false)
                    
                    Spacer()
                    
                    Text("false")
                        .fontWeight(.thin)
                        .forgroundColor(.red)
                }
                .newLine()
                
                Group {
                    Text("Text.fontWeight(_ weight: Weight)")
                        .fontWeight(.thin)
                    
                    Spacer()
                    
                    Text(".thin")
                        .fontWeight(.thin)
                        .forgroundColor(.red)
                }
                .newLine()
                
                Text("Text.italic()")
                    .italic()
                    .newLine()
                
                Group {
                    Text("Text.italic(_ isActive: Bool)")
                        .italic(false)
                    
                    Spacer()
                    
                    Text("false")
                        .fontWeight(.thin)
                        .forgroundColor(.red)
                }
                .newLine()
                
                Text("Text.underline()")
                    .underline()
                    .newLine()
                
                Group {
                    Text("Text.underline(_ isActive: Bool)")
                        .underline(false)
                    
                    Spacer()
                    
                    Text("false")
                        .fontWeight(.thin)
                        .forgroundColor(.red)
                }
                .newLine()
                
                Group {
                    Text("Text.blink(_ style: BlinkStyle)")
                        .blink(.default)
                    
                    Spacer()
                    
                    Text(".default")
                        .fontWeight(.thin)
                        .forgroundColor(.red)
                }
                .newLine()
                
                Text("Text.hidden()")
                    .hidden()
                    .newLine()
                
                Group {
                    Text("Text.hidden(_ isActive: Bool)")
                        .hidden(false)
                    
                    Spacer()
                    
                    Text("false")
                        .fontWeight(.thin)
                        .forgroundColor(.red)
                }
                .newLine()
                
                Text("Text.strikethrough()")
                    .strikethrough()
                    .newLine()
                
                Group {
                    Text("Text.strikethrough(_ isActive: Bool)")
                        .strikethrough(false)
                    
                    Spacer()
                    
                    Text("false")
                        .fontWeight(.thin)
                        .forgroundColor(.red)
                }
                .newLine()
            }
        }
        
        group.render()
    }
}
