//
//  Label.swift
//  SwiftLI
//  
//  Created by Keisuke Chinone on 2024/07/23.
//


import ArgumentParser
import SwiftLI


struct LabelCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "label",
        abstract: "Display of Label structure",
        discussion: """
        Command to check the display of Label structure
        """,
        version: "0.0.2",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )
    
    mutating func run() {
        let logo = Group {
            Text("Label View")
                .background(Color.white)
                .forgroundColor(Color.blue)
                .bold()
                .newLine()
            
            Group {
                Group {
                    Label("init(_ title: String,unicodeImage: Int)", unicodeImage: 0x2705)
                        .forgroundColor(Color.cyan)
                    
                    Spacer()
                    
                    Text("\"init(_ title: String,unicodeImage: Int)\",0x2705")
                        .fontWeight(.thin)
                        .forgroundColor(.red)
                }
                .newLine()
            }
        }
        
        logo.render()
    }
}
