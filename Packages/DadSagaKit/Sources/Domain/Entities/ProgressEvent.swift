import Foundation

/// Something the dad completed or captured. The game never takes XP away; only the dad can remove his own entry.
public struct ProgressEvent: Hashable, Identifiable, Sendable {
    public enum Kind: Hashable, Sendable {
        case quest(id: String)
        case boss(id: String)
        case first(id: String)

        /// A boss or a first counts once per child; a quest can be done again and again.
        public var countsOncePerChild: Bool {
            switch self {
            case .quest: false
            case .boss, .first: true
            }
        }
    }

    public let id: UUID
    /// Who recorded it: a player's id (`PlayerProfile.id`). Any id, since a copy may hold a partner's entries
    /// (ADR-0065 §5). An edit never changes it.
    public let authorID: UUID
    public let kind: Kind
    /// The child it happened with. Every event has one (ADR-0026).
    public let childID: UUID
    /// When it happened. For a first, the day the dad says it happened, which may be in the past.
    public let date: Date
    /// The dad's own words, for firsts.
    public let note: String?
    /// Photos kept on the device, in the dad's order; the first is the cover (ADR-0042). At most `photoLimit`.
    public let photoIDs: [String]

    /// The most photos an entry keeps (ADR-0042).
    public static let photoLimit = 5

    /// The photo shown wherever the entry has one picture: thumbnails, the widget, the film's cards.
    public var coverPhotoID: String? { photoIDs.first }

    public init(
        id: UUID = UUID(),
        authorID: UUID,
        kind: Kind,
        childID: UUID,
        date: Date,
        note: String? = nil,
        photoIDs: [String] = []
    ) {
        self.id = id
        self.authorID = authorID
        self.kind = kind
        self.childID = childID
        self.date = date
        self.note = note
        self.photoIDs = photoIDs
    }
}
