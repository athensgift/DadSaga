import SwiftData

extension PersistentModel {
    /// Sets the column at `keyPath` only when the value differs. Whether SwiftData counts an equal assignment as a change
    /// is undocumented, and a change is what sync sends to the partner (ADR-0065, Risks), so an equal value is never
    /// assigned. Key paths are written inline at each call, inside the repository's actor, never stored.
    func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<Self, Value>, to value: Value) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }
}
