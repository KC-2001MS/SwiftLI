//
//  Group.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/28.
//


import ArgumentParser
import SwiftLI

struct GroupCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "group",
        abstract: "Display of Group structure",
        discussion: """
        Command to check the display of Group structure
        """,
        version: "0.0.1",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )
    
    mutating func run() {
        let group = Group {
            Text("Group View")
                .background(Color.white)
                .forgroundColor(Color.blue)
                .bold()
            
            Break(1)
            
            Group {
                Text("Group(@ViewBuilder contents: () -> [View])")
                    .forgroundColor(Color.cyan)
                
                Group {
                    Text("Group")
                }
            }
            .newLine()
        }
        
        group.render()
    }
}
