//
//  ViewBuilder.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/27.
//

@resultBuilder
/// A custom parameter attribute that constructs views from closures.
public struct ViewBuilder {
    /// Produces content
    public static func buildBlock(_ components: View...) -> [View] {
        return components
    }
    /// Produces content
    public static func buildOptional(_ component: [View]?) -> [View] {
           component ?? []
    }
    /// Produces content for a conditional statement in a multi-statement closure when the condition is true.
    public static func buildEither(first component: [View]) -> [View] {
        component
    }
    /// Produces content for a conditional statement in a multi-statement closure when the condition is false.
    public static func buildEither(second component: [View]) -> [View] {
        component
    }
    /// Produces content
    public static func buildArray(_ components: [[View]]) -> [View]  {
        components.flatMap({ $0 })
    }
    /// Processes view content for a conditional compiler-control statement that performs an availability check.
    public static func buildLimitedAvailability(_ component: [View]) -> [View] {
           component
    }
}
