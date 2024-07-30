//
//  SwiftLI.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/27.
//


import ArgumentParser

//https://100rabh.medium.com/cli-tool-in-swift-using-swift-argument-parser-subcommands-and-flags-77ee31d9ac99
@main
struct scltCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sclt",
        abstract: "Command line tool to check SwiftLI operation",
        discussion: """
        A set of commands to check the behavior of various UI components
        """,
        version: "0.0.2",
        subcommands: [
            TextCommand.self,
            SpacerCommand.self,
            BreakCommand.self,
            GroupCommand.self,
            HDividerCommand.self,
            LabelCommand.self,
            SwiftLogoCommand.self
        ],
        defaultSubcommand: TextCommand.self,
        helpNames: [.long, .short]
    )
}
