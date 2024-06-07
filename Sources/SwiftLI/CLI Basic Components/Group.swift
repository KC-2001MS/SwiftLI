//
//  Group.swift
//  
//  
//  Created by Keisuke Chinone on 2024/05/27.
//


/// View for grouping multiple views together
public struct Group: View {
    private var contents: [View]
    /// Creates a group of views.
    /// - Parameter contents: A ViewBuilder that produces the views to group.
    public init(@ViewBuilder contents: () -> [View]) {
        self.contents = contents()
    }
    /// What the view displays
    public var body: [View] {
        return contents
    }
}
