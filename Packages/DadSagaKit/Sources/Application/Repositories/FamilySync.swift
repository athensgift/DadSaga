/// Where the saga syncs (ADR-0065 §1, §4): for the iCloud and sharing pages, the export page and start over.
public struct ShareStatus: Hashable, Sendable {
    public enum Sharing: Hashable, Sendable {
        /// Never on, turned off, purged, or another account: nothing leaves the iPhone.
        case off
        /// On, with no partner in the family.
        case alone
        /// On, the family in this parent's iCloud, a partner in it.
        case owner
        /// On, the family in the partner's iCloud.
        case partner
    }

    /// What sync waits for. The saga is untouched meanwhile, and its changes are kept to send.
    public enum Waiting: Hashable, Sendable {
        /// Until the same Apple Account returns.
        case signedOut
        /// `isPartners`: it is the iCloud of the family's owner that is full, not this parent's.
        case iCloudFull(isPartners: Bool)
        /// This parent's iCloud names another family: the parent is asked before this iPhone follows it.
        case followFamily
    }

    public var sharing: Sharing
    public var waiting: Waiting?

    public init(sharing: Sharing, waiting: Waiting? = nil) {
        self.sharing = sharing
        self.waiting = waiting
    }
}

/// Port for sync (ADR-0065 §8). Turning on, joining, following and ending come with the screens that ask for them.
public protocol FamilySync: Sendable {
    func status() async -> ShareStatus
    /// Once at launch (ADR-0081). With iCloud off it trims the store's history, so it never grows. With it on (the
    /// co-op version, which may also call it on returning to the foreground), it gives every waiting change again and
    /// sends what the iPhone has that iCloud lacks (an offer answered, a photo).
    func resume() async
}
