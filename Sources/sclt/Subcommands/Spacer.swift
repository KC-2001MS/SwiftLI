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
        Command to check the display of Spacer structure
        """,
        version: "0.0.2",
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
                        .fontWeight(.thin)
                        .forgroundColor(.red)
                }
                .newLine()
            }
            
            Group {
                Group {
                    Text("init(_ count: Int)")
                        .forgroundColor(Color.cyan)
                    
                    Spacer()
                    
                    Text("2")
                        .fontWeight(.thin)
                        .forgroundColor(.red)
                }
                .newLine()
                
                Group {
                    Spacer(2)
                    
                    Text("← Spacer(2)")
                        .fontWeight(.thin)
                        .forgroundColor(.red)
                }
                .newLine()
            }
        }
        
        group.render()
    }
}
