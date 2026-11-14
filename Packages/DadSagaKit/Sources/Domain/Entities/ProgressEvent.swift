import Foundation

/// Something the dad completed or captured. Events only ever add XP; nothing is ever taken away.
public struct ProgressEvent: Hashable, Identifiable, Sendable {
    public enum Kind: Hashable, Sendable {
        case quest(id: String)
        case boss(id: String)
        case first(id: String)
    }

    public let id: UUID
    public let kind: Kind
    /// The child it happened with. `nil` only for events that were never linked to a child.
    public let childID: UUID?
    public let date: Date

    public init(id: UUID = UUID(), kind: Kind, childID: UUID? = nil, date: Date) {
        self.id = id
        self.kind = kind
        self.childID = childID
        self.date = date
    }
}
