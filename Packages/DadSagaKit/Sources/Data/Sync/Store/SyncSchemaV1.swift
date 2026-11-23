import Foundation
import SwiftData

/// Sync's bookkeeping, in `Sync.store` beside the saga's store and never in it (ADR-0065 §5): what waits to be sent,
/// each record's system fields, the history token, the children deleted for good. It ships with the co-op version;
/// until then it changes in place, as `SchemaV1` did before 1.0 (ADR-0067 §3). Every model has one row per key
/// (`#Unique`), and no write relies on the upsert a unique column does: a row is fetched, then updated or inserted.
enum SyncSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            SyncSettingsRecord.self, PendingChangeRecord.self, SystemFieldsRecord.self, GoneChildRecord.self,
            EngineStateRecord.self, KnownPhotoRecord.self, MemberRecord.self
        ]
    }

    /// The one row of settings.
    @Model
    final class SyncSettingsRecord {
        #Unique<SyncSettingsRecord>([\.key])

        /// Always `SyncSettingsRecord.onlyKey`: the store keeps exactly one.
        var key: String
        /// Whether the saga syncs. False until iCloud is turned on, and again once sync turns itself off.
        var isOn: Bool
        /// `SyncOffReason`: why sync turned itself off; nil: it was never on, or is on.
        var offReason: String?
        /// The real user record name of the Apple Account iCloud was turned on for, kept through a sign-out.
        var accountName: String?
        /// `SyncPause`: what sync waits for while on; nil: nothing.
        var pause: String?
        /// `SyncDatabase`: whose iCloud is full while the pause is `iCloudFull`.
        var fullDatabase: String?
        /// The family's zone, `Family-<this id>`, in the iCloud of `familyOwner`.
        var familyZoneID: UUID?
        /// The real user record name of the parent whose iCloud holds the family; `accountName`: this parent's.
        var familyOwner: String?
        /// The saga store's history token the change feed read through (`DefaultHistoryToken`, as JSON). Nil: read
        /// from the start of the history.
        var historyToken: Data?
        /// The history token expired: once the next fetch ends, every row the server lacks is sent (ADR-0065 §2).
        var resendAfterFetch: Bool
        /// The family's zone is to be fetched whole: nothing of the family is sent until that fetch ends, and then what
        /// goes follows the rejoin's rule (ADR-0065 §2, "A full send with no change token").
        var fullSendAfterFetch: Bool
        /// `ChildMap`, as JSON: this parent's children to the family's, from the last join or follow; it travels in
        /// `saga`.
        var childMap: Data?
        /// `childMap` is still to be applied: the family's children it names have not all come yet.
        var childMapWaits: Bool
        /// `saga` names the family only once the zone holds everything that waited for it (ADR-0065 §4).
        var sagaWaitsForFamily: Bool
        /// This parent's own family zone that a join left: deleted once the joined family holds its entries.
        var oldFamilyZoneID: UUID?
        /// `saga` names another family than this iPhone syncs with: its zone, to follow once the parent says so
        /// (ADR-0065 §4). The family's sync waits meanwhile; the parent's own zone goes on.
        var followZoneID: UUID?
        var followOwner: String?
        /// `saga`'s `childMap` as it came.
        var followChildMap: Data?
        /// `SagaChange`: how that family came to be this parent's; nil reads as merged.
        var followHow: String?

        init(historyToken: Data?, resendAfterFetch: Bool) {
            key = Self.onlyKey
            isOn = false
            self.historyToken = historyToken
            self.resendAfterFetch = resendAfterFetch
            fullSendAfterFetch = false
            childMapWaits = false
            sagaWaitsForFamily = false
        }

        static let onlyKey = "sync"
    }

    /// One record's change waiting to be sent. It holds field names, never values: the values are read from the row
    /// when a batch is built, so a later edit rides along and a row deleted meanwhile is skipped.
    @Model
    final class PendingChangeRecord {
        #Unique<PendingChangeRecord>([\.scope, \.recordName])

        /// `SyncScope`: `personal`, or `family` for the family zone `Sync.store` names now.
        var scope: String
        var recordName: String
        var isDeletion: Bool
        /// The fields the dad changed, which are the ones a record that comes leaves alone; empty for a deletion.
        var fields: [String]
        /// The record goes whole, whatever `fields` says: the row was inserted, or the zone isn't known to hold it.
        var allFields: Bool
        /// A deletion followed by a save of every field: a record written again for a new creator, since a
        /// modification keeps the creator (ADR-0065 §2, members).
        var thenSave: Bool
        /// Grows with every change merged in. A sent batch removes the row only at the revision it was built from.
        var revision: Int
        /// Held until the next fetch ends: it says whether the record or its zone went (ADR-0065 §4).
        var behindFetch: Bool
        /// The order changes were first made in.
        var sequence: Int

        init(scope: String, recordName: String, isDeletion: Bool, fields: [String], allFields: Bool, sequence: Int) {
            self.scope = scope
            self.recordName = recordName
            self.isDeletion = isDeletion
            self.fields = fields
            self.allFields = allFields
            thenSave = false
            revision = 1
            behindFetch = false
            self.sequence = sequence
        }
    }

    /// The system fields of a record the server holds, as last saved or fetched: a save sets its fields on the record
    /// rebuilt from them (ADR-0065 §4). A record without a row was never sent.
    @Model
    final class SystemFieldsRecord {
        #Unique<SystemFieldsRecord>([\.scope, \.recordName])

        var scope: String
        var recordName: String
        var data: Data

        init(scope: String, recordName: String, data: Data) {
            self.scope = scope
            self.recordName = recordName
            self.data = data
        }
    }

    /// A child deleted for good, on this iPhone or learned from a fetched marker: every zone this iPhone builds carries
    /// their `gone` record, so nothing brings them back (ADR-0065 §4).
    @Model
    final class GoneChildRecord {
        #Unique<GoneChildRecord>([\.childID])

        var childID: UUID

        init(childID: UUID) {
            self.childID = childID
        }
    }

    /// What one database's engine last reported of itself, handed back when the engine is next made (ADR-0065 §2).
    @Model
    final class EngineStateRecord {
        #Unique<EngineStateRecord>([\.database])

        /// `SyncDatabase`.
        var database: String
        var state: Data

        init(database: String, state: Data) {
            self.database = database
            self.state = state
        }
    }

    /// A photo whose record the family's zone holds, and the entry it was sent or fetched for: an entry's photos to
    /// delete come from comparing its `photoIDs` with these (ADR-0065 §2).
    @Model
    final class KnownPhotoRecord {
        #Unique<KnownPhotoRecord>([\.photoID])

        var photoID: String
        var entryID: UUID

        init(photoID: String, entryID: UUID) {
            self.photoID = photoID
            self.entryID = entryID
        }
    }

    /// A parent in the family: a `member-` record that names the account that created it (ADR-0065 §2). A record
    /// someone else wrote for them is not one.
    @Model
    final class MemberRecord {
        #Unique<MemberRecord>([\.profileID])

        var profileID: UUID
        /// The real user record name of the parent's Apple Account.
        var userRecordName: String

        init(profileID: UUID, userRecordName: String) {
            self.profileID = profileID
            self.userRecordName = userRecordName
        }
    }
}
