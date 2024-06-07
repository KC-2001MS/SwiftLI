//
//  Spacer.swift
//  
//  
//  Created by Keisuke Chinone on 2024/05/28.
//


import ArgumentParser
import SwiftLI

struct SpacerCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "spacer",
        abstract: "Display of HSpacer structure",
        discussion: """
        Command to check the display of HSpacer structure
        """,
        version: "0.0.1",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )
    
    mutating func run() {
        let group = Group {
            Text("Spacer View")
                .background(Color.white)
                .forgroundColor(Color.blue)
                .bold()
            
            Break(1)
            
            Group {
                Text("init()")
                    .forgroundColor(Color.cyan)
                    .newLine()
                
                Group {
                    Spacer()
                    
                    Text("← Spacer()")
                }
                .newLine()
            }
            
            Group {
                Text("init(_ count: Int)")
                    .forgroundColor(Color.cyan)
                    .newLine()
                
                Group {
                    Spacer(2)
                    
                    Text("← Spacer(2)")
                }
                .newLine()
            }
        }
        
        group.render()
    }
}
