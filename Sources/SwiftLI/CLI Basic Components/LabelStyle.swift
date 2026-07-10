//
//  LabelStyle.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2024/07/26.
//


/// The configuration passed to a ``LabelStyle`` when building its body.
///
/// A `LabelStyleConfiguration` bundles the icon and title views that a
/// ``Label`` was initialized with. Conformers of ``LabelStyle`` receive this
/// value in ``LabelStyle/makeBody(configuration:)`` and use it to compose the
/// final layout.
public struct LabelStyleConfiguration {

    /// The icon component of the label (e.g. an emoji or ASCII symbol).
    public let icon: AnyView

    /// The title component of the label (plain text).
    public let title: AnyView
}

/// A type that controls how a ``Label``'s icon and title are arranged.
///
/// Conform to `LabelStyle` and implement ``makeBody(configuration:)`` to
/// create a fully custom label layout. Apply your style with
/// ``Label/labelStyle(_:)``.
///
/// ```swift
/// struct BracketedLabelStyle: LabelStyle {
///     func makeBody(configuration: Configuration) -> some View {
///         HStack {
///             Text(verbatim: "[")
///             configuration.icon
///             Text(verbatim: "] ")
///             configuration.title
///         }
///     }
/// }
///
/// Label("Save", unicodeImage: 0x1F4BE)
///     .labelStyle(BracketedLabelStyle())
///     .render()
/// // [💾] Save
/// ```
///
/// ## Built-in styles
///
/// | Static accessor | Type | Layout |
/// | --------------- | ---- | ------ |
/// | `.automatic`    | ``DefaultLabelStyle``       | icon · space · title |
/// | `.iconOnly`     | ``IconOnlyLabelStyle``      | icon only |
/// | `.titleOnly`    | ``TitleOnlyLabelStyle``     | title only |
/// | `.titleAndIcon` | ``TitleAndIconLabelStyle``  | icon · space · title |
public protocol LabelStyle {
    /// An alias for ``LabelStyleConfiguration``.
    typealias Configuration = LabelStyleConfiguration

    /// The view type this style produces.
    associatedtype Body: View

    /// Constructs the view representing this label style.
    ///
    /// - Parameter configuration: The icon and title views provided by the ``Label``.
    /// - Returns: The laid-out icon and/or title.
    @ViewBuilder
    func makeBody(configuration: Self.Configuration) -> Body
}

/// The default label style — renders the icon, a single space, then the title.
///
/// This style is applied automatically when no explicit ``LabelStyle`` is set.
/// Equivalent to ``LabelStyle/automatic``.
public struct DefaultLabelStyle: LabelStyle {
    /// Creates the default label style.
    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 1) {
            configuration.icon
            configuration.title
        }
    }
}

/// A label style that renders only the icon, hiding the title.
///
/// Apply via ``LabelStyle/iconOnly``:
///
/// ```swift
/// Label("Save", unicodeImage: 0x1F4BE).labelStyle(.iconOnly).render()
/// // 💾
/// ```
public struct IconOnlyLabelStyle: LabelStyle {
    /// Creates the icon-only label style.
    public func makeBody(configuration: Configuration) -> some View {
        configuration.icon
    }
}

/// A label style that renders only the title, hiding the icon.
///
/// Apply via ``LabelStyle/titleOnly``:
///
/// ```swift
/// Label("Save", unicodeImage: 0x1F4BE).labelStyle(.titleOnly).render()
/// // Save
/// ```
public struct TitleOnlyLabelStyle: LabelStyle {
    /// Creates the title-only label style.
    public func makeBody(configuration: Configuration) -> some View {
        configuration.title
    }
}

/// A label style that renders the icon, a single space, then the title
/// (identical layout to ``DefaultLabelStyle``).
///
/// Apply via ``LabelStyle/titleAndIcon``:
///
/// ```swift
/// Label("Save", unicodeImage: 0x1F4BE).labelStyle(.titleAndIcon).render()
/// // 💾 Save
/// ```
public struct TitleAndIconLabelStyle: LabelStyle {
    /// Creates the title-and-icon label style.
    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 1) {
            configuration.icon
            configuration.title
        }
    }
}

public extension LabelStyle where Self == DefaultLabelStyle {
    /// The default label style: icon · space · title.
    static var automatic: Self { .init() }
}

public extension LabelStyle where Self == IconOnlyLabelStyle {
    /// A label style that shows only the icon.
    static var iconOnly: Self { .init() }
}

public extension LabelStyle where Self == TitleOnlyLabelStyle {
    /// A label style that shows only the title.
    static var titleOnly: Self { .init() }
}

public extension LabelStyle where Self == TitleAndIconLabelStyle {
    /// A label style that shows the icon and title (same layout as `.automatic`).
    static var titleAndIcon: Self { .init() }
}
