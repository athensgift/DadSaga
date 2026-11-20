import SwiftData

/// Every stored version, oldest first, and how to move between them (ADR-0026).
///
/// Several photos per entry take two steps (ADR-0042 §2). V1 → V2 adds `photoIDs` beside `photoID`. V2 → V3 copies
/// each `photoID` into an empty `photoIDs` on version 2, where both columns exist, then drops `photoID`. The copy
/// captures nothing and can run twice; if anything fails, the store stays at version 1 or 2 with every photo id, and
/// the next launch carries on. V3 → V4 adds the dad's look as four optional columns (ADR-0044 §6).
enum DadSagaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self] }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .custom(fromVersion: SchemaV2.self, toVersion: SchemaV3.self, willMigrate: copyPhotoIDs, didMigrate: nil),
            .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self)
        ]
    }

    /// Each event's one photo becomes its list of photos.
    private static func copyPhotoIDs(in context: ModelContext) throws {
        for record in try context.fetch(FetchDescriptor<SchemaV2.ProgressEventRecord>()) where record.photoIDs.isEmpty {
            if let photoID = record.photoID { record.photoIDs = [photoID] }
        }
        try context.save()
    }
}

/// The version the app reads and writes. The rest of Data names records through these.
typealias CurrentSchema = SchemaV4
typealias ProfileRecord = CurrentSchema.ProfileRecord
typealias ChildRecord = CurrentSchema.ChildRecord
typealias ProgressEventRecord = CurrentSchema.ProgressEventRecord
typealias OutfitRecord = CurrentSchema.OutfitRecord
