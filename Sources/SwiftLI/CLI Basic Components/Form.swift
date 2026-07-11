//
//  Form.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/11.
//


/// A container that groups controls used for data entry.
///
/// Mirrors SwiftUI's `Form`: stack ``Section``s of ``TextField``s,
/// ``Toggle``s, ``Picker``s and other controls, and the form lays them out as
/// a labelled, readable column — one blank line between sections. Focus flows
/// through the contained controls with <kbd>Tab</kbd> as usual.
///
/// ```swift
/// Form {
///     Section("Account") {
///         TextField("Name", text: $name)
///         TextField("Email", text: $email)
///     }
///     Section("Options") {
///         Toggle("Notifications", isOn: $notifies)
///         Picker("Theme", selection: $theme, options: ["Light", "Dark"])
///     }
/// }
/// ```
public struct Form: View {
    let content: [any View]

    /// Creates a form from its content — typically ``Section``s of controls.
    ///
    /// - Parameter content: A ``ViewBuilder`` producing the form's content.
    public init<Content: View>(@ViewBuilder content: () -> Content) {
        self.content = content()._flattenedChildren()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 1, children: content)
    }
}
