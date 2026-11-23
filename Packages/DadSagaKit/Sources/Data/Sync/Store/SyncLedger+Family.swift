import Foundation
import SwiftData

/// The family in `Sync.store` (ADR-0065 §2, §4): its members, the family `saga` names, and the zone the saga moves to
/// by a join, a follow or a rebuild. As in the rest of the ledger, every method is one turn and one save.
extension SyncLedger {
    // MARK: Members

    /// The family's members: each parent's profile id, and the account their `member-` record names.
    func members() throws -> [UUID: String] {
        Dictionary(
            try modelContext.fetch(FetchDescriptor<MemberRecord>()).map { ($0.profileID, $0.userRecordName) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// A fetched `member-` record: a member when it names the account that created it, and none otherwise, so a
    /// record written for someone else never makes them one (ADR-0065 §2). Inside a save.
    func keep(member record: SyncRecord) throws {
        guard let profileID = record.name.uuid else { return }
        if let account = record.memberAccount {
            try know(member: profileID, of: account)
        } else if let row = try memberRow(profileID) {
            modelContext.delete(row)
        }
    }

    func know(member profileID: UUID, of account: String) throws {
        if let row = try memberRow(profileID) {
            row.update(\.userRecordName, to: account)
        } else {
            modelContext.insert(MemberRecord(profileID: profileID, userRecordName: account))
        }
    }

    func memberRow(_ profileID: UUID) throws -> MemberRecord? {
        try modelContext.fetch(FetchDescriptor<MemberRecord>(predicate: #Predicate { $0.profileID == profileID })).first
    }

    // MARK: The family `saga` names

    /// A `saga` that came, against the family this iPhone syncs with (ADR-0065 §4): another family is kept to follow
    /// once the parent says so, and the same one ends that. Not while this iPhone's own `saga` is still to be
    /// written: what the zone holds then is the one it replaces. Inside a save.
    func compare(saga record: SyncRecord, _ turn: inout Turn) throws {
        let row = try settingsRowMakingOne()
        guard !row.sagaWaitsForFamily, try self.row(.saga, &turn) == nil, let family = record.sagaFamily else { return }
        follow(family.zoneID == row.familyZoneID && family.owner == row.familyOwner ? nil : family, row)
    }

    private func follow(_ family: FamilyToFollow?, _ row: SyncSettingsRecord) {
        row.update(\.followZoneID, to: family?.zoneID)
        row.update(\.followOwner, to: family?.owner)
        row.update(\.followChildMap, to: family?.childMap)
        row.update(\.followHow, to: family?.how)
    }

    /// Nothing is left of a join, a follow or a rebuild under way, but the parent's own zone a join left, which is
    /// still to delete. Inside a save.
    func endFamilyMoves(_ row: SyncSettingsRecord) {
        row.update(\.fullSendAfterFetch, to: false)
        row.update(\.childMapWaits, to: false)
        row.update(\.sagaWaitsForFamily, to: false)
        follow(nil, row)
    }

    // MARK: Moving to another zone

    /// The saga moves into a family's zone that holds records already: a join, a rejoin, a follow (ADR-0065 §2, §4).
    /// Nothing kept of the zone it leaves meets the new one, and what waited for the family still waits: it merges
    /// into the new zone once that has been fetched whole, by an engine that starts from nothing. `map` is applied
    /// when the family's children it names are here. `writingSaga`: this iPhone made the move, so `saga` names the
    /// family once the zone holds everything that waited, and the parent's own zone it left is deleted then; an
    /// iPhone that follows writes neither.
    func attach(family: (id: UUID, owner: String), map: ChildMap, writingSaga: Bool) throws {
        try modelContext.saveAllOrNothing {
            let row = try settingsRowMakingOne()
            let isOwn = family.owner == row.accountName
            if writingSaga, let old = row.familyZoneID, row.familyOwner == row.accountName, !(isOwn && old == family.id) {
                row.update(\.oldFamilyZoneID, to: old)
            }
            endFamilyMoves(row)
            row.update(\.familyZoneID, to: family.id)
            row.update(\.familyOwner, to: family.owner)
            row.update(\.fullSendAfterFetch, to: true)
            row.update(\.sagaWaitsForFamily, to: writingSaga)
            if !map.moves.isEmpty {
                row.update(\.childMap, to: map.json)
                row.update(\.childMapWaits, to: true)
            }
            try forgetZone(SyncScope.family.rawValue)
            for pending in try waiting(.family) { pending.update(\.behindFetch, to: false) }
            try forgetEngine(.shared)
            guard isOwn else { return }
            // The parent's own database is fetched from nothing too: what their own zone lacks afterwards is sent.
            try forgetEngine(.private)
            try forgetZone(SyncScope.personal.rawValue)
            row.update(\.resendAfterFetch, to: true)
        }
    }

    /// The account iCloud was turned on for is back after a sign-out (ADR-0065 §4). An engine starts from nothing
    /// after it, and a fetch from nothing reports no deletion, so a row deleted meanwhile would stay on this iPhone
    /// only: the family's zone is fetched whole again and the rejoin's rule decides, as after a join. Nothing kept
    /// of the zone stays, and what waits still waits.
    func accountReturned() throws {
        try modelContext.saveAllOrNothing {
            let row = try settingsRowMakingOne()
            row.update(\.pause, to: nil)
            row.update(\.fullDatabase, to: nil)
            row.update(\.fullSendAfterFetch, to: true)
            try forgetZone(SyncScope.family.rawValue)
            for pending in try waiting(.family) { pending.update(\.behindFetch, to: false) }
            try forgetEngine(row.familyOwner == row.accountName ? .private : .shared)
        }
    }

    /// The family's zone went with the partner's sharing (ADR-0065 §4): the saga goes whole into a new zone of this
    /// parent's own, every record of `names`, and `saga` names it once it holds them.
    func rebuild(family id: UUID, sending names: [RecordName]) throws {
        try modelContext.saveAllOrNothing {
            let row = try settingsRowMakingOne()
            endFamilyMoves(row)
            row.update(\.familyZoneID, to: id)
            row.update(\.familyOwner, to: row.accountName)
            row.update(\.sagaWaitsForFamily, to: true)
            try forgetEngine(.shared)
            try restart([.family], sending: names)
        }
    }

    private func waiting(_ scope: SyncScope) throws -> [PendingChangeRecord] {
        let scope = scope.rawValue
        return try modelContext.fetch(FetchDescriptor<PendingChangeRecord>(predicate: #Predicate { $0.scope == scope }))
    }

    private func forgetEngine(_ database: SyncDatabase) throws {
        if let row = try engineRow(database) { modelContext.delete(row) }
    }

    // MARK: The child map

    /// The part of the waiting child map that was applied: it is the one `saga` carries. A change that waited for a
    /// child whose row went finds no row when its batch is built, and is dropped there. Inside a save.
    func applied(_ map: ChildMap) throws {
        let row = try settingsRowMakingOne()
        row.update(\.childMap, to: map.moves.isEmpty ? nil : map.json)
        row.update(\.childMapWaits, to: false)
    }

    func mapped(_ map: ChildMap) throws {
        try modelContext.saveAllOrNothing { try applied(map) }
    }

    // MARK: After the whole fetch

    /// The records of `scope` the zone is known to hold: those whose system fields are kept.
    func heldNames(_ scope: SyncScope) throws -> Set<RecordName> {
        let scope = scope.rawValue
        let rows = try modelContext.fetch(FetchDescriptor<SystemFieldsRecord>(predicate: #Predicate { $0.scope == scope }))
        return Set(rows.compactMap { RecordName($0.recordName) })
    }

    /// The family's zone has been fetched whole, and what it lacks is sent (ADR-0065 §2): each of `names` goes whole,
    /// unless the zone turns out to hold it. Each of `again` is deleted and then written: a member's record that
    /// another account created, since a modification would keep that creator. The family's changes wait no longer.
    func fullSend(_ names: [RecordName], writingAgain again: [RecordName]) throws {
        try modelContext.saveAllOrNothing {
            var turn = Turn(nextSequence: try nextSequence())
            try merge(neverSent: names, &turn)
            for name in again {
                let row = try row(name, &turn) ?? insert(name, isDeletion: true, fields: [], whole: false, &turn)
                row.update(\.isDeletion, to: true)
                row.update(\.allFields, to: false)
                row.update(\.fields, to: [])
                row.update(\.thenSave, to: true)
                row.revision += 1
            }
            try settingsRowMakingOne().update(\.fullSendAfterFetch, to: false)
        }
    }

    /// Once nothing waits for the family's zone any more, `saga` names the family (ADR-0065 §4): the parent's other
    /// iPhones follow a zone that holds everything. Returns whether `saga` was given to send just now.
    func familySent() throws -> Bool {
        try modelContext.saveAllOrNothing {
            guard let row = try settingsRow(), row.sagaWaitsForFamily, !row.fullSendAfterFetch, row.followZoneID == nil
            else { return false }
            guard try waiting(.family).isEmpty else { return false }
            row.update(\.sagaWaitsForFamily, to: false)
            var turn = Turn(nextSequence: try nextSequence())
            try merge(save: .saga, fields: nil, &turn)
            return true
        }
    }

    /// The parent's own zone a join left is deleted.
    func oldZoneDeleted(_ id: UUID) throws {
        try modelContext.saveAllOrNothing {
            guard let row = try settingsRow(), row.oldFamilyZoneID == id else { return }
            row.update(\.oldFamilyZoneID, to: nil)
        }
    }
}
