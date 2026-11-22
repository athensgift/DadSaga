import Foundation

/// A copy of the saga: what a file the dad exports holds, and what importing it brings back (ADR-0057 §2). The phone's
/// own settings (appearance, haptics, the reminder, the film sheet's choices) are not in it.
public struct SagaCopy: Hashable, Sendable {
    public var saga: StoredSaga
    /// The film offers the dad answered (ADR-0037 §5), so a restored saga doesn't offer them again.
    public var answeredOccasionIDs: Set<String>
    /// When the copy was made, shown before it replaces anything.
    public var madeAt: Date

    public init(saga: StoredSaga, answeredOccasionIDs: Set<String>, madeAt: Date) {
        self.saga = saga
        self.answeredOccasionIDs = answeredOccasionIDs
        self.madeAt = madeAt
    }
}
