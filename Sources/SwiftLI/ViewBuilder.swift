//
//  ViewBuilder.swift
//  
//  Created by Keisuke Chinone on 2024/05/27.
//

@resultBuilder
/// A custom parameter attribute that constructs views from closures.
public struct ViewBuilder {
    /// Produces content from a list of child views, wrapping them in a ``Group``.
    public static func buildBlock(_ components: any View...) -> Group {
        Group(contents: components)
    }
    /// Produces content for an optional child view.
    public static func buildOptional(_ component: Group?) -> Group {
        component ?? Group(contents: [])
    }
    /// Produces content for a conditional statement when the condition is true.
    public static func buildEither(first component: Group) -> Group {
        component
    }
    /// Produces content for a conditional statement when the condition is false.
    public static func buildEither(second component: Group) -> Group {
        component
    }
    /// Produces content from an array of groups (for `for` loops).
    public static func buildArray(_ components: [Group]) -> Group {
        Group(contents: components.flatMap { $0.contents })
    }
    /// Processes view content for a conditional compiler-control statement that performs an availability check.
    public static func buildLimitedAvailability(_ component: Group) -> Group {
        component
    }
    /// Wraps a single expression as a Group.
    public static func buildExpression(_ expression: any View) -> Group {
        Group(contents: [expression])
    }
}
