import Domain
import Foundation
import SwiftData

/// Every stored version, oldest first, and how to move between them (ADR-0026).
///
/// Several photos per entry take two steps (ADR-0042 §2). V1 → V2 adds `photoIDs` beside `photoID`. V2 → V3 copies
/// each `photoID` into an empty `photoIDs` on version 2, where both columns exist, then drops `photoID`. The copy
/// captures nothing and can run twice; if anything fails, the store stays at version 1 or 2 with every photo id, and
/// the next launch carries on. V3 → V4 adds the dad's look as four optional columns (ADR-0044 §6). V4 → V5 adds each
/// child's birth day as three optional columns and fills them from the stored moment, read in the phone's time zone:
/// the zone the dad picked it in (ADR-0048 §2). A row left empty still reads from `birthDate`.
enum DadSagaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .custom(fromVersion: SchemaV2.self, toVersion: SchemaV3.self, willMigrate: copyPhotoIDs, didMigrate: nil),
            .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self),
            .custom(
                fromVersion: SchemaV4.self,
                toVersion: SchemaV5.self,
                willMigrate: nil,
                didMigrate: { try fillBirthDays(in: $0, timeZone: .autoupdatingCurrent) }
            )
        ]
    }

    /// Each event's one photo becomes its list of photos.
    private static func copyPhotoIDs(in context: ModelContext) throws {
        for record in try context.fetch(FetchDescriptor<SchemaV2.ProgressEventRecord>()) where record.photoIDs.isEmpty {
            if let photoID = record.photoID { record.photoIDs = [photoID] }
        }
        try context.save()
    }

    /// Each child's stored moment becomes the day it falls on in `timeZone`. Rows that have a day keep it, so it can run
    /// twice.
    static func fillBirthDays(in context: ModelContext, timeZone: TimeZone) throws {
        for record in try context.fetch(FetchDescriptor<SchemaV5.ChildRecord>()) where record.birthYear == nil {
            let day = CalendarDay(record.birthDate, in: timeZone)
            record.birthYear = day.year
            record.birthMonth = day.month
            record.birthDay = day.day
        }
        try context.save()
    }
}

/// The version the app reads and writes. The rest of Data names records through these.
typealias CurrentSchema = SchemaV5
typealias ProfileRecord = CurrentSchema.ProfileRecord
typealias ChildRecord = CurrentSchema.ChildRecord
typealias ProgressEventRecord = CurrentSchema.ProgressEventRecord
typealias OutfitRecord = CurrentSchema.OutfitRecord
