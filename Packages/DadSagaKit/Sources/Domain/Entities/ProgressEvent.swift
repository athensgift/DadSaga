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
    /// When it happened. For a first, the day the dad says it happened, which may be in the past.
    public let date: Date
    /// The dad's own words, for firsts.
    public let note: String?

    public init(id: UUID = UUID(), kind: Kind, childID: UUID? = nil, date: Date, note: String? = nil) {
        self.id = id
        self.kind = kind
        self.childID = childID
        self.date = date
        self.note = note
    }
}
