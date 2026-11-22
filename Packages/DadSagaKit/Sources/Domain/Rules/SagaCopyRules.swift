import Foundation

/// Why a saga read from a copy can't be stored as it is.
public enum SagaCopyRuleError: Error, Equatable, Sendable {
    /// None, or more than `PlayerProfile.maxChildren`.
    case childCount
    case duplicateChild
    case emptyChildName
    case duplicateEntry
    /// An entry with more than `ProgressEvent.photoLimit` photos.
    case tooManyPhotos
    /// One photo on two entries, or twice on one: deleting one entry would take it from the other.
    case sharedPhoto
}

/// What a saga from a copy must be before it replaces the one on the phone (ADR-0057 §7): what the store itself can't
/// hold or the app could never have written.
///
/// Deliberately not checked: content ids and the hero (unknown ones are handled as everywhere, ADR-0048 §5), a birth
/// day after today (a copy made in another time zone), and an entry whose child has left the family (the app keeps
/// those too).
public enum SagaCopyRules {
    public static func checked(_ saga: StoredSaga) throws(SagaCopyRuleError) {
        let children = saga.profile.children
        guard (1...PlayerProfile.maxChildren).contains(children.count) else { throw .childCount }
        guard Set(children.map(\.id)).count == children.count else { throw .duplicateChild }
        guard children.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw .emptyChildName
        }
        guard Set(saga.events.map(\.id)).count == saga.events.count else { throw .duplicateEntry }
        guard saga.events.allSatisfy({ $0.photoIDs.count <= ProgressEvent.photoLimit }) else { throw .tooManyPhotos }
        let photoIDs = saga.photoIDs
        guard Set(photoIDs).count == photoIDs.count else { throw .sharedPhoto }
    }
}
