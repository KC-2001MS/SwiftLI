//
//  SwiftLI.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/27.
//


import ArgumentParser

//https://100rabh.medium.com/cli-tool-in-swift-using-swift-argument-parser-subcommands-and-flags-77ee31d9ac99
@main
struct scltCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sclt",
        abstract: "Command line tool to check SwiftLI operation",
        discussion: """
        A set of commands to check the behavior of various UI components
        """,
        version: "0.0.3",
        subcommands: [
            TextCommand.self,
            SpacerCommand.self,
            GroupCommand.self,
            DividerCommand.self,
            LabelCommand.self,
            EmoticonCommand.self,
            SwiftLogoCommand.self,
            ProgressViewCommand.self,
            HStackCommand.self,
            VStackCommand.self,
            DashboardCommand.self,
            TimelineCommand.self,
            TextFieldCommand.self,
            TextEditorCommand.self,
            ToggleCommand.self,
            PickerCommand.self,
            ScrollCommand.self,
            FrameCommand.self,
            TableCommand.self,
            ListCommand.self
        ],
        defaultSubcommand: TextCommand.self,
        helpNames: [.long, .short]
    )
}
