import Foundation
import SwiftData

/// Why sync turned itself off (ADR-0065 §4). Nothing is uploaded again until the parent turns iCloud on.
enum SyncOffReason: String, Sendable {
    /// The parent deleted DadSaga's data in iCloud's settings.
    case purged
    /// Another Apple Account is signed in: nothing goes into another person's iCloud by itself.
    case otherAccount
    /// Another of the parent's iPhones deleted the zone (it started over).
    case zoneDeleted
}

/// What sync waits for while it is on (ADR-0065 §4). Changes are kept in `Sync.store` meanwhile.
enum SyncPause: String, Sendable {
    /// Until the account iCloud was turned on for returns.
    case signedOut
    /// Until there is room; tried again at the next launch.
    case iCloudFull
}

/// A copy of `Sync.store`'s one row of settings.
struct SyncSettings: Hashable, Sendable {
    /// The saga store's history was read through this token; nil: from its start.
    var historyToken: DefaultHistoryToken?
    var resendAfterFetch: Bool
    var isOn = false
    var offReason: SyncOffReason?
    /// The real user record name iCloud was turned on for.
    var account: String?
    var pause: SyncPause?
    var fullDatabase: SyncDatabase?
    var familyZoneID: UUID?
    var familyOwner: String?
    /// The family's zone is to be fetched whole before anything of the family is sent (ADR-0065 §2).
    var fullSendAfterFetch = false
    /// This parent's children to the family's, from the last join or follow.
    var childMap: ChildMap?
    /// `childMap` is still to be applied.
    var childMapWaits = false
    var sagaWaitsForFamily = false
    var oldFamilyZoneID: UUID?
    /// The family `saga` names, when it is not the one this iPhone syncs with.
    var follow: FamilyToFollow?

    /// The family's zone, once iCloud has been turned on.
    var familyZone: SyncZone? {
        guard let familyZoneID, let familyOwner else { return nil }
        return .family(familyZoneID, owner: familyOwner)
    }

    var zones: SyncZones? { familyZone.map(SyncZones.init) }

    /// Personal is in this parent's private database; the family is there too when it is theirs, and in the shared
    /// one when it is the partner's (ADR-0065 §2).
    func database(for scope: SyncScope) -> SyncDatabase {
        scope == .family && familyOwner != account ? .shared : .private
    }

    /// The databases the saga syncs with, each through an engine of its own.
    var databases: [SyncDatabase] {
        database(for: .family) == .shared ? [.private, .shared] : [.private]
    }

    /// Which kind of zone `zone` is for this saga; nil for a zone it doesn't sync with.
    func scope(of zone: SyncZone) -> SyncScope? {
        if zone == .personal { return .personal }
        return zone == familyZone ? .family : nil
    }

    /// Whether changes for `database` wait for room in its iCloud.
    func isFull(_ database: SyncDatabase) -> Bool {
        pause == .iCloudFull && fullDatabase == database
    }

    /// What `saga` says: the family, and the child map of the last join. A field with nothing to say is cleared, so
    /// one an earlier `saga` carried never stays.
    var sagaFields: [String: SyncValue]? {
        guard let familyZoneID, let familyOwner else { return nil }
        let map = childMap?.json.flatMap { String(bytes: $0, encoding: .utf8) }
        return [
            SyncField.Saga.familyZone: .string(familyZoneID.uuidString), SyncField.Saga.familyOwner: .string(familyOwner),
            SyncField.Saga.childMap: map.map(SyncValue.string) ?? .cleared, SyncField.Saga.how: .cleared
        ]
    }

    /// Whether the family's changes wait in `Sync.store`: until the parent follows the family `saga` names, or until
    /// the family's zone has been fetched whole (ADR-0065 §2, §4). The parent's own zone goes on meanwhile.
    var familyWaits: Bool { follow != nil || fullSendAfterFetch }
}

/// The family `saga` names while this iPhone syncs with another (ADR-0065 §4): the parent is asked once to follow it.
struct FamilyToFollow: Hashable, Sendable {
    let zoneID: UUID
    /// The real user record name of the parent whose iCloud holds it.
    let owner: String
    /// This parent's children to that family's, as `saga` carries it; nil: the same children.
    let childMap: Data?
    /// How the family came to be this parent's, as `saga` says it; nil: by a join, a leave or a stop.
    let how: String?

    var zone: SyncZone { .family(zoneID, owner: owner) }

    /// Following merges what this iPhone has into the family. Anything else replaces this iPhone's saga with the
    /// zone's (an import, "which to keep"), and its question says so.
    var merges: Bool { how == nil }
}

/// One record's change waiting to be sent.
struct PendingChange: Hashable, Sendable {
    let name: RecordName
    let isDeletion: Bool
    /// The fields to set, read from the row when the batch is built; nil: every field. Empty for a deletion.
    let fields: Set<String>?
    /// What a batch remembers, to tell `sent` which state of the change it carried.
    let revision: Int
    /// Not given to an engine until the next fetch ends.
    let behindFetch: Bool
}
