import Foundation
import SwiftData
import Testing
@testable import Data

/// Each id is kept in the store's history when its row is deleted, so a change can name the row it took (ADR-0065 §5).
/// `SchemaV1` freezes with the first release, so the shape is pinned now.
@Suite("Ids kept when a row is deleted")
struct StoreHistoryTests {
    @Test("Given one row of each model on disk, when each is deleted, then the history names every one by its id")
    func deletionsKeepTheirIDs() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-history-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let container = try ModelContainer(
            for: Schema(versionedSchema: CurrentSchema.self),
            migrationPlan: DadSagaMigrationPlan.self,
            configurations: [ModelConfiguration(url: directory.appending(path: "DadSaga.store"), cloudKitDatabase: .none)]
        )
        let context = ModelContext(container)
        let (profileID, childID, eventID) = (UUID(), UUID(), UUID())
        let rows = Self.rows(profileID: profileID, childID: childID, eventID: eventID)
        rows.forEach { context.insert($0) }
        try context.save()
        rows.forEach { context.delete($0) }
        try context.save()

        var profiles: [UUID?] = [], children: [UUID?] = [], events: [UUID?] = [], skills: [String?] = []
        for transaction in try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()) {
            for change in transaction.changes {
                guard case .delete(let deletion) = change else { continue }
                switch deletion {
                case let deletion as DefaultHistoryDelete<ProfileRecord>:
                    profiles.append(deletion.tombstone[\.profileID] as? UUID)
                case let deletion as DefaultHistoryDelete<ChildRecord>:
                    children.append(deletion.tombstone[\.childID] as? UUID)
                case let deletion as DefaultHistoryDelete<ProgressEventRecord>:
                    events.append(deletion.tombstone[\.eventID] as? UUID)
                case let deletion as DefaultHistoryDelete<OutfitRecord>:
                    skills.append(deletion.tombstone[\.skill] as? String)
                default:
                    Issue.record("An unexpected deletion: \(deletion)")
                }
            }
        }

        #expect(profiles == [profileID])
        #expect(children == [childID])
        #expect(events == [eventID])
        #expect(skills == ["care"])
    }

    /// One row of each model.
    private static func rows(profileID: UUID, childID: UUID, eventID: UUID) -> [any PersistentModel] {
        [
            ProfileRecord(
                profileID: profileID, heroClassID: "h", dadSkinTone: "dark", hairStyle: "short", hairColor: "red",
                beard: "none", glasses: "none", hasPartner: true
            ),
            ChildRecord(
                childID: childID, name: "Λένα", birthYear: nil, birthMonth: nil, birthDay: nil, gender: "girl",
                skinTone: "dark", order: 0, isRemoved: false
            ),
            ProgressEventRecord(
                eventID: eventID, authorID: profileID, kind: "quest", contentID: "q", childID: childID, date: .now,
                note: nil, photoIDs: []
            ),
            OutfitRecord(skill: "care", choice: "hidden")
        ]
    }
}
