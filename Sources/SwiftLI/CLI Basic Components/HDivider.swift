//
//  HDivider.swift
//
//  
//  Created by Keisuke Chinone on 2024/05/28.
//


public struct HDivider: View {
    private let count: Int
    
    private var string: String
    
    private var header: String
    /// Creates a space view that is displayed in the terminal.
    /// - Parameter count: Space Width
    public init(_ count: Int) {
        self.count = count
        self.string = "-"
        self.header = ""
    }
    
    private init(header: String,string: String,count: Int) {
        self.count = count
        self.string = string
        self.header = header
    }
    /// What the view displays
    public var body: [View] {
        Text(header: header,repeating: string, count: count)
    }
    
    public func lineStyle(_ style: LineStyle) -> HDivider {
        switch style {
        case .default:
            return .init(header: self.header, string: "-", count: self.count)
        case .double_line:
            return .init(header: self.header, string: "=", count: self.count)
        }
    }
    
    public func forgroundColor(_ color: Color) -> HDivider {
        return .init(header: "\(header)\u{001B}[3\(color.name)m", string: string, count: count)
    }
}

public enum LineStyle {
    case `default`
    case double_line
}
