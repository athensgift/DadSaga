import Foundation

/// Something the dad completed or captured. The game never takes XP away; only the dad can remove his own entry.
public struct ProgressEvent: Hashable, Identifiable, Sendable {
    public enum Kind: Hashable, Sendable {
        case quest(id: String)
        case boss(id: String)
        case first(id: String)
    }

    public let id: UUID
    public let kind: Kind
    /// The child it happened with. Every event has one (ADR-0026).
    public let childID: UUID
    /// When it happened. For a first, the day the dad says it happened, which may be in the past.
    public let date: Date
    /// The dad's own words, for firsts.
    public let note: String?
    /// Identifier of a photo kept on the device, for firsts.
    public let photoID: String?

    public init(
        id: UUID = UUID(),
        kind: Kind,
        childID: UUID,
        date: Date,
        note: String? = nil,
        photoID: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.childID = childID
        self.date = date
        self.note = note
        self.photoID = photoID
    }
}
