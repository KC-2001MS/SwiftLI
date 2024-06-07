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
            
            Text("init()")
                .forgroundColor(Color.cyan)
                .newLine()
            
            Text("Break() →")
            
            Break()
            
            Text("init(_ count: Int)")
                .forgroundColor(Color.cyan)
                .newLine()
            
            Text("Break(1) →")
            
            Break(1)
        }
        
        group.render()
    }
}
