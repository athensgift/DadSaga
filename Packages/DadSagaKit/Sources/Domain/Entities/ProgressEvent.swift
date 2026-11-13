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
    public let date: Date

    public init(id: UUID = UUID(), kind: Kind, date: Date) {
        self.id = id
        self.kind = kind
        self.date = date
    }
}
