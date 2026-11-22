import Foundation

/// Everything the store keeps of one saga, read or written as a whole: what a copy of the saga carries (ADR-0057 §2).
/// Content ids are kept exactly as stored, known or not (ADR-0057 §5).
public struct StoredSaga: Hashable, Sendable {
    public var profile: PlayerProfile
    /// The children removed from the family (ADR-0065 §4): on no screen and in no count, kept so a copy carries them
    /// again. Until the co-op version only a copy can bring one; their entries are in `events` and still count.
    public var removedChildren: [Child]
    /// Every entry, oldest first.
    public var events: [ProgressEvent]
    public var outfit: Outfit
    public var kept: KeptStanding

    public init(
        profile: PlayerProfile,
        removedChildren: [Child],
        events: [ProgressEvent],
        outfit: Outfit,
        kept: KeptStanding
    ) {
        self.profile = profile
        self.removedChildren = removedChildren
        self.events = events
        self.outfit = outfit
        self.kept = kept
    }

    /// Every entry's photos, entry by entry, in the dad's order.
    public var photoIDs: [String] { events.flatMap(\.photoIDs) }

    /// The same saga with each photo id replaced by `newIDs[id]`. An id with no replacement leaves its entry; the
    /// others keep their order, so the cover stays the cover when it has one.
    public func replacingPhotoIDs(_ newIDs: [String: String]) -> StoredSaga {
        var saga = self
        saga.events = events.map { event in
            ProgressEvent(
                id: event.id, authorID: event.authorID, kind: event.kind, childID: event.childID, date: event.date,
                note: event.note,
                photoIDs: event.photoIDs.compactMap { newIDs[$0] }
            )
        }
        return saga
    }
}
