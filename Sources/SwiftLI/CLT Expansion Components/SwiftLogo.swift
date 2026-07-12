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
    
    /// The content and layout of the Swift logo view.
    public var body: some View {
        VStack {
            HStack {
                Text(repeating: ".", count: 32)
            }
            .padding(.leading, 10)


            HStack {
                Text(".")
                Text(repeating: ":", count: 36)
                Text(".")
            }
            .padding(.leading, 7)


            HStack {
                Text(".")
                Text(repeating: ":", count: 40)
                Text(".")
            }
            .padding(.leading, 5)


            HStack {
                Text(".")
                Text(repeating: ":", count: 24)
                Text("-").forgroundColor(Color.primary)

                Text(repeating: ":", count: 17)
                Text(".")
            }
            .padding(.leading, 4)


            HStack {
                Text(".")
                Text(repeating: ":", count: 26)
                Text("##=").forgroundColor(Color.primary)

                Text(repeating: ":", count: 15)
                Text(".")
            }
            .padding(.leading, 3)


            HStack {
                Text(".")
                Text(repeating: ":", count: 12)
                Text("=-").forgroundColor(Color.primary)

                Text(repeating: ":", count: 13)
                Text("%@%=").forgroundColor(Color.primary)

                Text(repeating: ":", count: 13)
                Text(".")
            }
            .padding(.leading, 3)


            HStack {
                Text(repeating: ":", count: 9)
                Text("+=").forgroundColor(Color.primary)

                Text(":::")
                Text("+*=").forgroundColor(Color.primary)
                Text(repeating: ":", count: 12)

                Text("@@@*").forgroundColor(Color.primary)
                Text(repeating: ":", count: 13)
            }
            .padding(.leading, 3)


            HStack {
                Text(repeating: ":", count: 10)
                Text("+#*").forgroundColor(Color.primary)
                Text("::")

                Text("=#%+").forgroundColor(Color.primary)
                Text(repeating: ":", count: 11)

                Text("@@@%").forgroundColor(Color.primary)
                Text(repeating: ":", count: 12)
            }
            .padding(.leading, 3)


            HStack {
                Text(repeating: ":", count: 12)
                Text("#@#=").forgroundColor(Color.primary)
                Text(":")

                Text("+@@*").forgroundColor(Color.primary)
                Text(repeating: ":", count: 9)

                Text("@@@@@").forgroundColor(Color.primary)
                Text(repeating: ":", count: 11)
            }
            .padding(.leading, 3)


            HStack {
                Text(repeating: ":", count: 13)
                Text("=%@@#+#@@#+").forgroundColor(Color.primary)

                Text(repeating: ":", count: 6)
                Text("@@@@@@").forgroundColor(Color.primary)

                Text(repeating: ":", count: 10)
            }
            .padding(.leading, 3)


            HStack {
                Text(repeating: ":", count: 15)
                Text("+%@@%#@@@@#+").forgroundColor(Color.primary)

                Text("::")
                Text("+@@@@@@*").forgroundColor(Color.primary)
                Text(repeating: ":", count: 9)
            }
            .padding(.leading, 3)


            HStack {
                Text(repeating: ":", count: 17)
                Text("+@@@@@@@@@@#@@@@@@@%").forgroundColor(Color.primary)

                Text(repeating: ":", count: 9)
            }
            .padding(.leading, 3)


            HStack {
                Text(":::::::::::::::::::")
                Text("*@@@@@@@@@@@@@@@@@").forgroundColor(Color.primary)

                Text(":::::::::")
            }
            .padding(.leading, 3)


            HStack {
                Text(":::::")
                Text("++").forgroundColor(Color.primary)
                Text("::::::::::::::")

                Text("*%@@@@@@@@@@@@@#").forgroundColor(Color.primary)
                Text(":::::::::")
            }
            .padding(.leading, 3)


            HStack {
                Text("::::::")
                Text("*@#*+").forgroundColor(Color.primary)
                Text("::::::::::::")

                Text("*@@@@@@@@@@@@%").forgroundColor(Color.primary)
                Text(":::::::::")
            }
            .padding(.leading, 3)


            HStack {
                Text(":::::::")
                Text("=#@@@@%%####%%@@@@@@@@@@@@@@@@%=").forgroundColor(Color.primary)

                Text(":::::::")
            }
            .padding(.leading, 3)


            HStack {
                Text(":::::::::")
                Text("=*%@@@@@@@@@@@@@@@@@@@@@@@@@@%").forgroundColor(Color.primary)

                Text(":::::::")
            }
            .padding(.leading, 3)


            HStack {
                Text("-::::::::::::")
                Text("*%@@@@@@@@@@@@@@@@#*").forgroundColor(Color.primary)

                Text("::")
                Text("*#@@").forgroundColor(Color.primary)
                Text("::::::-")
            }
            .padding(.leading, 3)


            HStack {
                Text("-::::::::::::::::")
                Text("+*#%%%@%%%#*").forgroundColor(Color.primary)

                Text(":::::::::")
                Text("#").forgroundColor(Color.primary)
                Text("::::::-")
            }
            .padding(.leading, 3)


            HStack {
                Text("-")
                Text(repeating: ":", count: 42)
                Text("-")
            }
            .padding(.leading, 4)


            HStack {
                Text("-")
                Text(repeating: ":", count: 40)
                Text("-")
            }
            .padding(.leading, 5)


            HStack {
                Text("-")
                Text(repeating: ":", count: 36)
                Text("-")
            }
            .padding(.leading, 7)


            HStack {
                Text(repeating: "-", count: 32)
            }
            .padding(.leading, 10)

        }
        .forgroundColor(Color.eight_bit(202))
    }
}
