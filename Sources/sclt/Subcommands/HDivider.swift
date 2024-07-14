//
//  HDivider.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/29.
//


import ArgumentParser
import SwiftLI

struct HDividerCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "hdivider",
        abstract: "Display of HDivider structure",
        discussion: """
        Command to check the display of HDivider structure
        """,
        version: "0.0.2",
        shouldDisplay: true,
        helpNames: [.long, .short]
    )
    
    mutating func run() {
        let group = Group {
            Text("HDivider View")
                .background(Color.white)
                .forgroundColor(Color.blue)
                .bold()
                .newLine()
            
            Group {
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
                    HDivider(1)
                    
                    Text("← HDivider(1)")
                        .fontWeight(.thin)
                        .forgroundColor(.red)
                }
                .newLine()
            }
        }
        
        group.render()
    }
}

