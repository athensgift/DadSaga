import Foundation
import SwiftData

/// Sync's bookkeeping, in `Sync.store` beside the saga's store and never in it (ADR-0065 §5): what waits to be sent,
/// each record's system fields, the history token, the children deleted for good. It ships with the co-op version;
/// until then it changes in place, as `SchemaV1` did before 1.0 (ADR-0067 §3). Every model has one row per key
/// (`#Unique`), and no write relies on the upsert a unique column does: a row is fetched, then updated or inserted.
enum SyncSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SyncSettingsRecord.self, PendingChangeRecord.self, SystemFieldsRecord.self, GoneChildRecord.self]
    }

    /// The one row of settings.
    @Model
    final class SyncSettingsRecord {
        #Unique<SyncSettingsRecord>([\.key])

        /// Always `SyncSettingsRecord.onlyKey`: the store keeps exactly one.
        var key: String
        /// The saga store's history token the change feed read through (`DefaultHistoryToken`, as JSON). Nil: read
        /// from the start of the history.
        var historyToken: Data?
        /// The history token expired: once the next fetch ends, every row the server lacks is sent (ADR-0065 §2).
        var resendAfterFetch: Bool

        init(historyToken: Data?, resendAfterFetch: Bool) {
            key = Self.onlyKey
            self.historyToken = historyToken
            self.resendAfterFetch = resendAfterFetch
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
        /// The fields to set; empty for a deletion, and unused while `allFields`.
        var fields: [String]
        /// The record goes whole: the row was inserted, or saved again after its deletion waited.
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
}
