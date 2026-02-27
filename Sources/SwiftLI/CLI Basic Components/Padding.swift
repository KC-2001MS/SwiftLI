//
//  Padding.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/05/27.
//

import Foundation

/// A view that wraps another view and adds blank space around it.
///
/// Do not create `PaddingView` directly — use the `.padding()` modifier on
/// any ``View`` instead:
///
/// ```swift
/// Text("Hello, SwiftLI!")
///     .padding(.leading, 4)
///     .newLine()
///     .render()
/// // Output:     Hello, SwiftLI!
/// ```
public struct PaddingView: View, @unchecked Sendable {
    private let wrapped: any View
    private let edges: Edge.Set
    private let length: Int

    init(wrapped: any View, edges: Edge.Set, length: Int) {
        self.wrapped = wrapped
        self.edges = edges
        self.length = length
    }

    @ViewBuilder
    public var body: [View] { Text(verbatim: "") }

    public func render() {
        let pad = String(repeating: " ", count: length)

        // top padding: blank lines before content
        if edges.contains(.top) {
            for _ in 0..<length {
                print("")
            }
        }

        if edges.contains(.leading) || edges.contains(.trailing) {
            // Capture wrapped output, then re-emit with leading/trailing padding
            let pipe = Pipe()
            let originalFd = dup(STDOUT_FILENO)
            dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

            wrapped.render()
            fflush(stdout)

            dup2(originalFd, STDOUT_FILENO)
            close(originalFd)
            pipe.fileHandleForWriting.closeFile()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""

            // Split into lines and re-emit with padding applied
            var lines = text.components(separatedBy: "\n")
            // Remove trailing empty element produced by a final \n
            if lines.last == "" { lines.removeLast() }

            for (i, line) in lines.enumerated() {
                let leading  = edges.contains(.leading)  ? pad : ""
                let trailing = edges.contains(.trailing) ? pad : ""
                let isLast = i == lines.count - 1
                print("\(leading)\(line)\(trailing)", terminator: isLast ? "" : "\n")
            }
        } else {
            wrapped.render()
        }

        // bottom padding: blank lines after content
        if edges.contains(.bottom) {
            for _ in 0..<length {
                print("")
            }
        }
    }
}

// MARK: - padding modifier on View

public extension View {

    /// Adds equal padding to all edges of this view.
    ///
    /// - Parameter length: The number of space characters to add on each edge.
    ///   Defaults to `1`.
    /// - Returns: A view with padding applied.
    func padding(_ length: Int = 1) -> PaddingView {
        PaddingView(wrapped: self, edges: .all, length: length)
    }

    /// Adds padding to the specified edges of this view.
    ///
    /// - Parameters:
    ///   - edges: The edges to pad. Use ``Edge/Set`` values such as `.leading`,
    ///     `.horizontal`, or `.all`.
    ///   - length: The number of space characters to add. Defaults to `1`.
    /// - Returns: A view with padding applied.
    func padding(_ edges: Edge.Set, _ length: Int = 1) -> PaddingView {
        PaddingView(wrapped: self, edges: edges, length: length)
    }
}
