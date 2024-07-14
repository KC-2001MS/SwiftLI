//
//  Break.swift
//  
//  
//  Created by Keisuke Chinone on 2024/05/28.
//


import ArgumentParser
import SwiftLI

struct BreakCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "break",
        abstract: "Display of Break structure",
        discussion: """
        Command to check the display of Break structure
        """,
        version: "0.0.2",
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
            
            Text("init()")
                .forgroundColor(Color.cyan)
                .newLine()
            
            Group {
                Break()
                
                Text("Break() ↑")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }
            .newLine()
            
            Group {
                Text("init(_ count: Int)")
                    .forgroundColor(Color.cyan)
                
                Spacer()
                
                Text("1")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }
            .newLine()
            
            Group {
                Break(1)
                
                Text("Break(1) ↑")
                    .fontWeight(.thin)
                    .forgroundColor(.red)
            }
            .newLine()
        }
        
        group.render()
    }
}
