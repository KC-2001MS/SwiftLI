//
//  example.swift
//  SwiftLI
//
//  Created by 茅根 啓介 on 2026/02/27.
//

// このファイルはSwiftLIの使用例を示すサンプルです。
// 以下のパターンを参考にしてください:
//
// import ArgumentParser
// import SwiftLI
//
// @main
// struct MyCommand: AsyncParsableCommand, ViewableCommand {
//     @State var value: Double = 0
//
//     let min = 0.0
//     let max = 100.0
//
//     static var configuration = CommandConfiguration(commandName: "my-command")
//
//     mutating func run() async throws {
//         print("bodyの前に表示される内容。更新で消えない。")
//         startBodyRendering()
//         for _ in 0..<1000 {
//             try await Task.sleep(nanoseconds: 100_000_000)
//             value = value + 0.1  // @State の変化で body が自動的に再描画される
//         }
//         stopBodyRendering()
//         print("bodyの後に表示される内容。更新で消えない。")
//     }
//
//     var body: some View {
//         ProgressBar(min: min, value: value, max: max)
//     }
// }
