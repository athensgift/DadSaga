import Foundation

/// Everything the store keeps of one saga, read or written as a whole: what a copy of the saga carries (ADR-0057 §2).
/// Content ids are kept exactly as stored, known or not (ADR-0057 §5).
public struct StoredSaga: Hashable, Sendable {
    public var profile: PlayerProfile
    /// Every entry, oldest first.
    public var events: [ProgressEvent]
    public var outfit: Outfit
    public var kept: KeptStanding

    public init(profile: PlayerProfile, events: [ProgressEvent], outfit: Outfit, kept: KeptStanding) {
        self.profile = profile
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
                id: event.id, kind: event.kind, childID: event.childID, date: event.date, note: event.note,
                photoIDs: event.photoIDs.compactMap { newIDs[$0] }
            )
        }
        return saga
    }
}
