//
//  StyleCarrying.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/11/08.
//

/// A view that stores a ``TextStyle`` of its own and resolves it when it
/// lowers — every rendering primitive, and the built-in controls.
///
/// The style modifiers (``View/bold()``, ``View/foregroundStyle(_:)``, …)
/// return `Self` for these views, so `Text("a").bold()` is still a `Text`.
/// For any other view they return a ``StyledView`` wrapper that cascades the
/// style onto the view's lowered content, which is what lets a custom
/// composite view take a style at all. Conform a custom view to this
/// protocol only when it implements `applyingStyle(_:)` itself.
public protocol _StyleCarryingView: View {}

extension Text: _StyleCarryingView {}
extension Spacer: _StyleCarryingView {}
extension Divider: _StyleCarryingView {}
extension Group: _StyleCarryingView {}
extension HStack: _StyleCarryingView {}
extension VStack: _StyleCarryingView {}
extension ForEach: _StyleCarryingView {}
extension AnyView: _StyleCarryingView {}
extension TupleView: _StyleCarryingView {}
extension _ConditionalContent: _StyleCarryingView {}
extension Optional: _StyleCarryingView where Wrapped: View {}
extension Emoticon: _StyleCarryingView {}
extension ContentUnavailableView: _StyleCarryingView {}
extension List: _StyleCarryingView {}
extension Table: _StyleCarryingView {}
extension Label: _StyleCarryingView {}
extension TextField: _StyleCarryingView {}
extension Picker: _StyleCarryingView {}
extension Stepper: _StyleCarryingView {}
extension Button: _StyleCarryingView {}
extension Link: _StyleCarryingView {}
extension ViewThatFits: _StyleCarryingView {}
extension ScrollView: _StyleCarryingView {}
extension Toggle: _StyleCarryingView {}
extension TimelineView: _StyleCarryingView {}
extension Slider: _StyleCarryingView {}
extension NavigationLink: _StyleCarryingView {}
extension StyledView: _StyleCarryingView {}
extension ModifiedContent: _StyleCarryingView {}
extension HitRegion: _StyleCarryingView {}
