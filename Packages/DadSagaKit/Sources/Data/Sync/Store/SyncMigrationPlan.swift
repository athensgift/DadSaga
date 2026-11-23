import SwiftData

/// `Sync.store`'s versions, oldest first (ADR-0065 §5). One version and no stage until the co-op version ships
/// (ADR-0067 §3).
enum SyncMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SyncSchemaV1.self] }

    static var stages: [MigrationStage] { [] }
}

/// The version sync reads and writes. The rest of Data names its records through these.
typealias CurrentSyncSchema = SyncSchemaV1
typealias SyncSettingsRecord = CurrentSyncSchema.SyncSettingsRecord
typealias PendingChangeRecord = CurrentSyncSchema.PendingChangeRecord
typealias SystemFieldsRecord = CurrentSyncSchema.SystemFieldsRecord
typealias GoneChildRecord = CurrentSyncSchema.GoneChildRecord
typealias EngineStateRecord = CurrentSyncSchema.EngineStateRecord
typealias KnownPhotoRecord = CurrentSyncSchema.KnownPhotoRecord
