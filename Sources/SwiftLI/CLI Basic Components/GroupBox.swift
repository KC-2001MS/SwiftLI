//
//  GroupBox.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/09.
//


/// A titled, bordered container that visually groups related content.
///
/// Mirrors SwiftUI's `GroupBox`: an optional bold title sits above the grouped
/// content, and the whole thing is wrapped in a rounded border with padding.
///
/// ```swift
/// GroupBox("Network") {
///     Text("Status: Connected")
///     Text("Latency: 24 ms")
/// }
/// .render()
/// ```
public struct GroupBox: View {
    let title: String?
    let content: [any View]

    /// Creates a group box with an optional title.
    ///
    /// - Parameters:
    ///   - title: An optional localized title shown at the top of the box.
    ///   - content: A ``ViewBuilder`` producing the grouped content.
    public init<Content: View>(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title.map { String(localized: $0.localizationValue) }
        self.content = content()._flattenedChildren()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0, children: items)
            .padding()
            .border(.rounded)
    }

    /// The stacked children: the bold title (when present) above the content.
    private var items: [any View] {
        var items: [any View] = []
        if let title {
            items.append(Text(content: title).bold())
        }
        items.append(contentsOf: content)
        return items
    }
}
