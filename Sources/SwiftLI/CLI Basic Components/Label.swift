//
//  Label.swift
//  SwiftLI
//  
//  Created by Keisuke Chinone on 2024/07/23.
//


public struct Label: View {
    let header: String
    
    let image: String
    
    let title: String
    
    let style: LabelStyle

    /// Initializer to realize method chain
    /// - Parameters:
    ///   - header: Hetter to specify display style
    ///   - title: String to display
    init(
        header: String,
        title: String,
        image: String,
        style: LabelStyle = .automatic
    ) {
        self.header = "\(header)"
        self.title = title
        self.image = image
        self.style = style
    }
    
    /// Creates a label view that is displayed in the terminal.
    /// - Parameters:
    ///   - title: Label Title
    ///   - unicodeImage: Unicode numbers for visual representation
    public init(
        _ title: LocalizedStringKey,
        unicodeImage: Int
    ) {
        let image: String
        // UnicodeScalarで初期化できるか確認
        if let scalar = UnicodeScalar(unicodeImage) {
            image = String(scalar)
        } else {
            // 初期化できない場合は空文字列を返す
            image = ""
        }
        self.header = ""
        self.image = image
        self.title = String(localized: title.localizationValue)
        self.style = .automatic
    }
    
    /// Creates a label view that is displayed in the terminal.
    /// - Parameters:
    ///   - image: String for visual representation
    ///   - title: Label Title
    public init(
        image: String,
        title: LocalizedStringKey
    ) {
        self.header = ""
        self.image = image
        self.title = String(localized: title.localizationValue)
        self.style = .automatic
    }
    
    /// What the view displays
    public var body: [any View] {
        return style.makeBody(configuration: LabelStyleConfiguration(icon: Text(content: image), title: Text(content: title)))
    }

    /// Methods for rendering text
    public func render() {
        Group(header: header, contents: body).render()
    }

    public func renderString() -> String {
        Group(header: header, contents: body).renderString()
    }

    public func labelStyle(_ style: LabelStyle) -> Self {
        return .init(header: self.header, title: self.header, image: self.image, style: style)
    }
}
