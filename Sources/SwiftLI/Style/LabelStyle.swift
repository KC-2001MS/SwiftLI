//
//  LabelStyle.swift
//  SwiftLI
//  
//  Created by Keisuke Chinone on 2024/07/26.
//


public struct LabelStyleConfiguration {
    var icon: View

    var title: View
}

public protocol LabelStyle {
    typealias Configuration = LabelStyleConfiguration

    @ViewBuilder
    func makeBody(configuration: Self.Configuration) -> [any View]
}

public struct DefaultLabelStyle: LabelStyle {
    public func makeBody(configuration: Configuration) -> [any View] {
            configuration.icon
            Spacer()
            configuration.title
    }
}

public struct IconOnlyLabelStyle: LabelStyle {
    public func makeBody(configuration: Configuration) -> [any View] {
            configuration.icon
    }
}

public struct TitleOnlyLabelStyle: LabelStyle {
    public func makeBody(configuration: Configuration) -> [any View] {
        configuration.title
    }
}

public struct TitleAndIconLabelStyle: LabelStyle {
    public func makeBody(configuration: Configuration) -> [any View] {
        configuration.icon
        Spacer()
        configuration.title
    }
}

public extension LabelStyle where Self == DefaultLabelStyle {
    static var automatic: Self { .init() }
}

public extension LabelStyle where Self == IconOnlyLabelStyle {
    static var iconOnly: Self { .init() }
}

public extension LabelStyle where Self == TitleOnlyLabelStyle {
    static var titleOnly: Self { .init() }
}

public extension LabelStyle where Self == TitleAndIconLabelStyle {
    static var titleAndIcon: Self { .init() }
}
