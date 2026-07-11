//
//  Bindable.swift
//  SwiftLI
//
//  Created by Keisuke Chinone on 2026/07/10.
//

import Observation

/// A property wrapper that creates bindings to the mutable properties of an
/// `@Observable` object — SwiftLI's counterpart to SwiftUI's `@Bindable`.
///
/// Use `@Bindable` when a view needs two-way access (`Binding`) to a property
/// of an observable model, for example to drive a ``TextField`` or ``Toggle``:
///
/// ```swift
/// @Observable
/// final class Settings: @unchecked Sendable {
///     var username = ""
///     var notificationsOn = false
/// }
///
/// struct SettingsView: View {
///     @Bindable var settings: Settings
///
///     var body: some View {
///         TextField("Name", text: $settings.username)
///         Toggle("Notifications", isOn: $settings.notificationsOn)
///     }
/// }
/// ```
///
/// Writing through a derived binding mutates the observable object directly,
/// so the change is picked up by the render loop's observation tracking (see
/// ``RenderObservation``) and the body is redrawn automatically.
///
/// You can also create one inline, without the property-wrapper syntax:
///
/// ```swift
/// let bindable = Bindable(settings)
/// TextField("Name", text: bindable.username)
/// ```
///
/// > Note: SwiftLI's ``Binding`` is `Sendable` (the render loop crosses
/// > threads), so the wrapped object must be `Sendable` as well — mark your
/// > `@Observable` class `Sendable` or `@unchecked Sendable` with appropriate
/// > internal synchronization.
@propertyWrapper
@dynamicMemberLookup
public struct Bindable<Value: AnyObject & Observable & Sendable>: Sendable {

    /// The observable object that bindings are derived from.
    public var wrappedValue: Value

    /// Creates a bindable from an observable object.
    /// - Parameter wrappedValue: The `@Observable` object to wrap.
    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    /// Creates a bindable from an observable object.
    /// - Parameter wrappedValue: The `@Observable` object to wrap.
    public init(_ wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    /// Creates a bindable from another bindable's projection, so `@Bindable`
    /// properties can be initialized from a passed-in `$model`.
    public init(projectedValue: Bindable<Value>) {
        self = projectedValue
    }

    /// The bindable itself; the `$` prefix exposes the dynamic-member
    /// subscript that derives ``Binding`` values.
    public var projectedValue: Bindable<Value> { self }

    /// Derives a ``Binding`` to a mutable property of the wrapped object.
    ///
    /// Reads go straight to the object (and are registered by observation
    /// tracking when they happen during a render pass); writes mutate the
    /// object, which triggers a re-render through ``RenderObservation``.
    public subscript<Subject: Sendable>(
        dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject> & Sendable
    ) -> Binding<Subject> {
        let object = wrappedValue
        return Binding(
            get: { object[keyPath: keyPath] },
            set: { object[keyPath: keyPath] = $0 }
        )
    }
}
