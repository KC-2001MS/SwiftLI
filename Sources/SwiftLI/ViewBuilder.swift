//
//  ViewBuilder.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/27.
//

@resultBuilder
public struct ViewBuilder {
    public static func buildBlock(_ components: View...) -> [View] {
        return components
    }
    
    public static func buildOptional(_ component: [View]?) -> [View] {
           component ?? []
    }
    
    public static func buildEither(first component: [View]) -> [View] {
        component
    }
    
    public static func buildEither(second component: [View]) -> [View] {
        component
    }
    
    public static func buildArray(_ components: [[View]]) -> [View]  {
        components.flatMap({ $0 })
    }
    
    public static func buildLimitedAvailability(_ component: [View]) -> [View] {
           component
    }
}
