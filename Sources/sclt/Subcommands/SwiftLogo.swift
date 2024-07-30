//
//  SwiftLogo.swift
//  SwiftLI
//  
//  Created by Keisuke Chinone on 2024/07/23.
//


import ArgumentParser
import SwiftLI

struct SwiftLogoCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift",
        abstract: "Display of SwiftLogo structure",
        discussion: """
        Command to check the display of SwiftLogo structure
        """,
        version: "0.0.2",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )
    
    mutating func run() {
        let logo = Group {
            Text("SwiftLogo View")
                .background(Color.white)
                .forgroundColor(Color.blue)
                .bold()
                .newLine()
            
            Group {
                Text("init()")
                    .forgroundColor(Color.cyan)
                    .newLine()
                
                    SwiftLogo()
                    
                    Break()
            }
            .newLine()
            
            Text("* This library was created by Swift.")
                .fontWeight(.thin)
                .newLine()
        }
        
        logo.render()
    }
}
