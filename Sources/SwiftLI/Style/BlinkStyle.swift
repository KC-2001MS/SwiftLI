//
//  BlinkStyle.swift
//  
//  
//  Created by Keisuke Chinone on 2024/05/28.
//


/// Blinking Method
public enum BlinkStyle: String, CaseIterable {
    case none = "0"
    case `default` = "5"
//    Removed because it does not work with macOS terminal app
//    case fast = "6"
}
