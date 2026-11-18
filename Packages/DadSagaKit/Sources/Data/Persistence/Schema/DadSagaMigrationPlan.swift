import SwiftData

/// Every stored version, oldest first, and how to move between them (ADR-0026).
enum DadSagaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

/// The version the app reads and writes. The rest of Data names records through these.
typealias CurrentSchema = SchemaV1
typealias ProfileRecord = CurrentSchema.ProfileRecord
typealias ChildRecord = CurrentSchema.ChildRecord
typealias ProgressEventRecord = CurrentSchema.ProgressEventRecord
typealias OutfitRecord = CurrentSchema.OutfitRecord
