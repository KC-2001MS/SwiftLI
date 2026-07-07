//
//  SwiftLogo.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/29.
//


/// A decorative ASCII-art view of the Swift programming language logo.
///
/// `SwiftLogo` renders a pre-composed, orange-tinted ASCII representation of
/// the Swift "swift bird" logo. No configuration is needed — simply create an
/// instance and call ``render()``.
///
/// ```swift
/// SwiftLogo().render()
/// ```
///
/// The logo is approximately 44 columns wide and 22 rows tall. Its color
/// is fixed to terminal 256-color palette index 202 (orange).
public struct SwiftLogo: View, Sendable, Equatable {
    /// Creates the Swift logo view.
    public init() {}
    
    public var body: some View {
        Group {
            HStack {
                Spacer(10)

                Text(repeating: ".", count: 32)
            }


            HStack {
                Spacer(7)

                Text(".")
                Text(repeating: ":", count: 36)
                Text(".")
            }


            HStack {
                Spacer(5)

                Text(".")
                Text(repeating: ":", count: 40)
                Text(".")
            }


            HStack {
                Spacer(4)

                Text(".")
                Text(repeating: ":", count: 24)
                Text("-").forgroundColor(Color.primary)

                Text(repeating: ":", count: 17)
                Text(".")
            }


            HStack {
                Spacer(3)

                Text(".")
                Text(repeating: ":", count: 26)
                Text("##=").forgroundColor(Color.primary)

                Text(repeating: ":", count: 15)
                Text(".")
            }


            HStack {
                Spacer(3)

                Text(".")
                Text(repeating: ":", count: 12)
                Text("=-").forgroundColor(Color.primary)

                Text(repeating: ":", count: 13)
                Text("%@%=").forgroundColor(Color.primary)

                Text(repeating: ":", count: 13)
                Text(".")
            }


            HStack {
                Spacer(3)

                Text(repeating: ":", count: 9)
                Text("+=").forgroundColor(Color.primary)

                Text(":::")
                Text("+*=").forgroundColor(Color.primary)
                Text(repeating: ":", count: 12)

                Text("@@@*").forgroundColor(Color.primary)
                Text(repeating: ":", count: 13)
            }


            HStack {
                Spacer(3)

                Text(repeating: ":", count: 10)
                Text("+#*").forgroundColor(Color.primary)
                Text("::")

                Text("=#%+").forgroundColor(Color.primary)
                Text(repeating: ":", count: 11)

                Text("@@@%").forgroundColor(Color.primary)
                Text(repeating: ":", count: 12)
            }


            HStack {
                Spacer(3)

                Text(repeating: ":", count: 12)
                Text("#@#=").forgroundColor(Color.primary)
                Text(":")

                Text("+@@*").forgroundColor(Color.primary)
                Text(repeating: ":", count: 9)

                Text("@@@@@").forgroundColor(Color.primary)
                Text(repeating: ":", count: 11)
            }


            HStack {
                Spacer(3)

                Text(repeating: ":", count: 13)
                Text("=%@@#+#@@#+").forgroundColor(Color.primary)

                Text(repeating: ":", count: 6)
                Text("@@@@@@").forgroundColor(Color.primary)

                Text(repeating: ":", count: 10)
            }


            HStack {
                Spacer(3)

                Text(repeating: ":", count: 15)
                Text("+%@@%#@@@@#+").forgroundColor(Color.primary)

                Text("::")
                Text("+@@@@@@*").forgroundColor(Color.primary)
                Text(repeating: ":", count: 9)
            }


            HStack {
                Spacer(3)

                Text(repeating: ":", count: 17)
                Text("+@@@@@@@@@@#@@@@@@@%").forgroundColor(Color.primary)

                Text(repeating: ":", count: 9)
            }


            HStack {
                Spacer(3)

                Text(":::::::::::::::::::")
                Text("*@@@@@@@@@@@@@@@@@").forgroundColor(Color.primary)

                Text(":::::::::")
            }


            HStack {
                Spacer(3)

                Text(":::::")
                Text("++").forgroundColor(Color.primary)
                Text("::::::::::::::")

                Text("*%@@@@@@@@@@@@@#").forgroundColor(Color.primary)
                Text(":::::::::")
            }


            HStack {
                Spacer(3)

                Text("::::::")
                Text("*@#*+").forgroundColor(Color.primary)
                Text("::::::::::::")

                Text("*@@@@@@@@@@@@%").forgroundColor(Color.primary)
                Text(":::::::::")
            }


            HStack {
                Spacer(3)

                Text(":::::::")
                Text("=#@@@@%%####%%@@@@@@@@@@@@@@@@%=").forgroundColor(Color.primary)

                Text(":::::::")
            }


            HStack {
                Spacer(3)

                Text(":::::::::")
                Text("=*%@@@@@@@@@@@@@@@@@@@@@@@@@@%").forgroundColor(Color.primary)

                Text(":::::::")
            }


            HStack {
                Spacer(3)

                Text("-::::::::::::")
                Text("*%@@@@@@@@@@@@@@@@#*").forgroundColor(Color.primary)

                Text("::")
                Text("*#@@").forgroundColor(Color.primary)
                Text("::::::-")
            }


            HStack {
                Spacer(3)

                Text("-::::::::::::::::")
                Text("+*#%%%@%%%#*").forgroundColor(Color.primary)

                Text(":::::::::")
                Text("#").forgroundColor(Color.primary)
                Text("::::::-")
            }


            HStack {
                Spacer(4)

                Text("-")
                Text(repeating: ":", count: 42)
                Text("-")
            }


            HStack {
                Spacer(5)

                Text("-")
                Text(repeating: ":", count: 40)
                Text("-")
            }


            HStack {
                Spacer(7)

                Text("-")
                Text(repeating: ":", count: 36)
                Text("-")
            }


            HStack {
                Spacer(10)

                Text(repeating: "-", count: 32)
            }

        }
        .forgroundColor(Color.eight_bit(202))
    }
}
