//
//  Section.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/11.
//


/// A titled slice of related content, for use inside containers like ``Form``
/// or ``List``.
///
/// Mirrors SwiftUI's `Section`: an optional header sits above the content and
/// an optional footer below it. In the terminal the header is rendered bold,
/// the content is indented two columns beneath it, and the footer is dimmed.
///
/// ```swift
/// Section("Account") {
///     TextField("Name", text: $name)
///     TextField("Email", text: $email)
/// }
/// ```
///
/// A custom header and footer are given as view builders:
///
/// ```swift
/// Section {
///     Toggle("Notifications", isOn: $notifies)
/// } header: {
///     Label("Options", unicodeImage: 0x2699)
/// } footer: {
///     Text("You can change this later.")
/// }
/// ```
public struct Section: View {
    let header: AnyView?
    let footer: AnyView?
    let content: [any View]

    /// Creates a section with an optional localized title.
    ///
    /// - Parameters:
    ///   - title: The heading shown above the content; omit for no header.
    ///   - content: A ``ViewBuilder`` producing the section's content.
    public init<Content: View>(_ title: LocalizedStringKey = "", @ViewBuilder content: () -> Content) {
        let resolved = title.resolve()
        self.header = resolved.isEmpty ? nil : AnyView(Text(content: resolved))
        self.footer = nil
        self.content = content()._flattenedChildren()
    }

    /// Creates a section with a custom header view.
    public init<Content: View, Header: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header
    ) {
        self.header = AnyView(header())
        self.footer = nil
        self.content = content()._flattenedChildren()
    }

    /// Creates a section with a custom footer view and no header.
    public init<Content: View, Footer: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.header = nil
        self.footer = AnyView(footer())
        self.content = content()._flattenedChildren()
    }

    /// Creates a section with custom header and footer views.
    public init<Content: View, Header: View, Footer: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer
    ) {
        self.header = AnyView(header())
        self.footer = AnyView(footer())
        self.content = content()._flattenedChildren()
    }

    /// The rendered output of the section: an optional bold header, indented
    /// content, and an optional dimmed footer.
    public var body: some View {
        if let header { header.bold() }
        VStack(alignment: .leading, spacing: 0, children: content)
            .padding(.leading, 2)
        if let footer {
            footer.forgroundColor(.eight_bit(240)).padding(.leading, 2)
        }
    }
}
