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
            HStack {
                Spacer(10)
                
                Text(repeating: ".", count: 32)
            }

            
            HStack {
                Spacer(7)
                
                Text(".") + Text(repeating: ":", count: 36) + Text(".")
            }

            
            HStack {
                Spacer(5)
                
                Text(".") + Text(repeating: ":", count: 40) + Text(".")
            }

            
            HStack {
                Spacer(4)
                
                Text(".") + Text(repeating: ":", count: 24) + Text("-").forgroundColor(Color.primary)
                
                Text(repeating: ":", count: 17) + Text(".")
            }

            
            HStack {
                Spacer(3)
                
                Text(".") + Text(repeating: ":", count: 26) + Text("##=").forgroundColor(Color.primary)
                
                Text(repeating: ":", count: 15) + Text(".")
            }

            
            HStack {
                Spacer(3)
                
                Text(".") + Text(repeating: ":", count: 12) + Text("=-").forgroundColor(Color.primary)
                
                Text(repeating: ":", count: 13) + Text("%@%=").forgroundColor(Color.primary)
                
                Text(repeating: ":", count: 13) + Text(".")
            }

            
            HStack {
                Spacer(3)
                
                Text(repeating: ":", count: 9) + Text("+=").forgroundColor(Color.primary)
                
                Text(":::") + Text("+*=").forgroundColor(Color.primary) + Text(repeating: ":", count: 12)
                
                Text("@@@*").forgroundColor(Color.primary) + Text(repeating: ":", count: 13)
            }

            
            HStack {
                Spacer(3)
                
                Text(repeating: ":", count: 10) + Text("+#*").forgroundColor(Color.primary) + Text("::")
                
                Text("=#%+").forgroundColor(Color.primary) + Text(repeating: ":", count: 11)
                
                Text("@@@%").forgroundColor(Color.primary) + Text(repeating: ":", count: 12)
            }

            
            HStack {
                Spacer(3)
                
                Text(repeating: ":", count: 12) + Text("#@#=").forgroundColor(Color.primary) + Text(":")
                
                Text("+@@*").forgroundColor(Color.primary) + Text(repeating: ":", count: 9)
                
                Text("@@@@@").forgroundColor(Color.primary) + Text(repeating: ":", count: 11)
            }

            
            HStack {
                Spacer(3)
                
                Text(repeating: ":", count: 13) + Text("=%@@#+#@@#+").forgroundColor(Color.primary)
                
                Text(repeating: ":", count: 6) + Text("@@@@@@").forgroundColor(Color.primary)
                
                Text(repeating: ":", count: 10)
            }

            
            HStack {
                Spacer(3)
                
                Text(repeating: ":", count: 15) + Text("+%@@%#@@@@#+").forgroundColor(Color.primary)
                
                Text("::") + Text("+@@@@@@*").forgroundColor(Color.primary) + Text(repeating: ":", count: 9)
            }

            
            HStack {
                Spacer(3)
                
                Text(repeating: ":", count: 17) + Text("+@@@@@@@@@@#@@@@@@@%").forgroundColor(Color.primary)
                
                Text(repeating: ":", count: 9)
            }

            
            HStack {
                Spacer(3)
                
                Text(":::::::::::::::::::") + Text("*@@@@@@@@@@@@@@@@@").forgroundColor(Color.primary)
                
                Text(":::::::::")
            }

            
            HStack {
                Spacer(3)
                
                Text(":::::") + Text("++").forgroundColor(Color.primary) + Text("::::::::::::::")
                
                Text("*%@@@@@@@@@@@@@#").forgroundColor(Color.primary) + Text(":::::::::")
            }

            
            HStack {
                Spacer(3)
                
                Text("::::::") + Text("*@#*+").forgroundColor(Color.primary) + Text("::::::::::::")
                
                Text("*@@@@@@@@@@@@%").forgroundColor(Color.primary) + Text(":::::::::")
            }

            
            HStack {
                Spacer(3)
                
                Text(":::::::") + Text("=#@@@@%%####%%@@@@@@@@@@@@@@@@%=").forgroundColor(Color.primary)
                
                Text(":::::::")
            }

            
            HStack {
                Spacer(3)
                
                Text(":::::::::") + Text("=*%@@@@@@@@@@@@@@@@@@@@@@@@@@%").forgroundColor(Color.primary)
                
                Text(":::::::")
            }

            
            HStack {
                Spacer(3)
                
                Text("-::::::::::::") + Text("*%@@@@@@@@@@@@@@@@#*").forgroundColor(Color.primary)
                
                Text("::") + Text("*#@@").forgroundColor(Color.primary) + Text("::::::-")
            }

            
            HStack {
                Spacer(3)
                
                Text("-::::::::::::::::") + Text("+*#%%%@%%%#*").forgroundColor(Color.primary)
                
                Text(":::::::::") + Text("#").forgroundColor(Color.primary) + Text("::::::-")
            }

            
            HStack {
                Spacer(4)
                
                Text("-") + Text(repeating: ":", count: 42) + Text("-")
            }

            
            HStack {
                Spacer(5)
                
                Text("-") + Text(repeating: ":", count: 40) + Text("-")
            }

            
            HStack {
                Spacer(7)
                
                Text("-") + Text(repeating: ":", count: 36) + Text("-")
            }

            
            HStack {
                Spacer(10)
                
                Text(repeating: "-", count: 32)
            }

        }
        .forgroundColor(Color.eight_bit(202))
    }
}
