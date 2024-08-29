//
//  SwiftLogo.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/29.
//


/// View displaying the Swift logo
public struct SwiftLogo: View, Sendable, Equatable {
    /// Initializer that initializes the view of the Swift logo
    public init() {}
    
    public var body: [View] {
        Group {
            Group {
                Spacer(10)
                
                Text(repeating: ".", count: 32)
            }
            .newLine()
            
            Group {
                Spacer(7)
                
                Text(".") + Text(repeating: ":", count: 36) + Text(".")
            }
            .newLine()
            
            Group {
                Spacer(5)
                
                Text(".") + Text(repeating: ":", count: 40) + Text(".")
            }
            .newLine()
            
            Group {
                Spacer(4)
                
                Text(".") + Text(repeating: ":", count: 24) + Text("-").forgroundColor(Color.primary)
                
                Text(repeating: ":", count: 17) + Text(".")
            }
            .newLine()
            
            Group {
                Spacer(3)
                
                Text(".") + Text(repeating: ":", count: 26) + Text("##=").forgroundColor(Color.primary)
                
                Text(repeating: ":", count: 15) + Text(".")
            }
            .newLine()
            
            Group {
                Spacer(3)
                
                Text(".") + Text(repeating: ":", count: 12) + Text("=-").forgroundColor(Color.primary)
                
                Text(repeating: ":", count: 13) + Text("%@%=").forgroundColor(Color.primary)
                
                Text(repeating: ":", count: 13) + Text(".")
            }
            .newLine()
            
            Group {
                Spacer(3)
                
                Text(repeating: ":", count: 9) + Text("+=").forgroundColor(Color.primary)
                
                Text(":::") + Text("+*=").forgroundColor(Color.primary) + Text(repeating: ":", count: 12)
                
                Text("@@@*").forgroundColor(Color.primary) + Text(repeating: ":", count: 13)
            }
            .newLine()
            
            Group {
                Spacer(3)
                
                Text(repeating: ":", count: 10) + Text("+#*").forgroundColor(Color.primary) + Text("::")
                
                Text("=#%+").forgroundColor(Color.primary) + Text(repeating: ":", count: 11)
                
                Text("@@@%").forgroundColor(Color.primary) + Text(repeating: ":", count: 12)
            }
            .newLine()
            
            Group {
                Spacer(3)
                
                Text(repeating: ":", count: 12) + Text("#@#=").forgroundColor(Color.primary) + Text(":")
                
                Text("+@@*").forgroundColor(Color.primary) + Text(repeating: ":", count: 9)
                
                Text("@@@@@").forgroundColor(Color.primary) + Text(repeating: ":", count: 11)
            }
            .newLine()
            
            Group {
                Spacer(3)
                
                Text(repeating: ":", count: 13) + Text("=%@@#+#@@#+").forgroundColor(Color.primary)
                
                Text(repeating: ":", count: 6) + Text("@@@@@@").forgroundColor(Color.primary)
                
                Text(repeating: ":", count: 10)
            }
            .newLine()
            
            Group {
                Spacer(3)
                
                Text(repeating: ":", count: 15) + Text("+%@@%#@@@@#+").forgroundColor(Color.primary)
                
                Text("::") + Text("+@@@@@@*").forgroundColor(Color.primary) + Text(repeating: ":", count: 9)
            }
            .newLine()
            
            Group {
                Spacer(3)
                
                Text(repeating: ":", count: 17) + Text("+@@@@@@@@@@#@@@@@@@%").forgroundColor(Color.primary)
                
                Text(repeating: ":", count: 9)
            }
            .newLine()
            
            Group {
                Spacer(3)
                
                Text(":::::::::::::::::::") + Text("*@@@@@@@@@@@@@@@@@").forgroundColor(Color.primary)
                
                Text(":::::::::")
            }
            .newLine()
            
            Group {
                Spacer(3)
                
                Text(":::::") + Text("++").forgroundColor(Color.primary) + Text("::::::::::::::")
                
                Text("*%@@@@@@@@@@@@@#").forgroundColor(Color.primary) + Text(":::::::::")
            }
            .newLine()
            
            Group {
                Spacer(3)
                
                Text("::::::") + Text("*@#*+").forgroundColor(Color.primary) + Text("::::::::::::")
                
                Text("*@@@@@@@@@@@@%").forgroundColor(Color.primary) + Text(":::::::::")
            }
            .newLine()
            
            Group {
                Spacer(3)
                
                Text(":::::::") + Text("=#@@@@%%####%%@@@@@@@@@@@@@@@@%=").forgroundColor(Color.primary)
                
                Text(":::::::")
            }
            .newLine()
            
            Group {
                Spacer(3)
                
                Text(":::::::::") + Text("=*%@@@@@@@@@@@@@@@@@@@@@@@@@@%").forgroundColor(Color.primary)
                
                Text(":::::::")
            }
            .newLine()
            
            Group {
                Spacer(3)
                
                Text("-::::::::::::") + Text("*%@@@@@@@@@@@@@@@@#*").forgroundColor(Color.primary)
                
                Text("::") + Text("*#@@").forgroundColor(Color.primary) + Text("::::::-")
            }
            .newLine()
            
            Group {
                Spacer(3)
                
                Text("-::::::::::::::::") + Text("+*#%%%@%%%#*").forgroundColor(Color.primary)
                
                Text(":::::::::") + Text("#").forgroundColor(Color.primary) + Text("::::::-")
            }
            .newLine()
            
            Group {
                Spacer(4)
                
                Text("-") + Text(repeating: ":", count: 42) + Text("-")
            }
            .newLine()
            
            Group {
                Spacer(5)
                
                Text("-") + Text(repeating: ":", count: 40) + Text("-")
            }
            .newLine()
            
            Group {
                Spacer(7)
                
                Text("-") + Text(repeating: ":", count: 36) + Text("-")
            }
            .newLine()
            
            Group {
                Spacer(10)
                
                Text(repeating: "-", count: 32)
            }
            .newLine()
        }
        .forgroundColor(Color.eight_bit(202))
    }
}
