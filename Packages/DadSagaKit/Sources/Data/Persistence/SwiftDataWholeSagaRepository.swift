import Application
import Domain
import Foundation
import SwiftData

/// `WholeSagaRepository` backed by SwiftData. Rows are fetched and deleted on one context, then saved once, so each
/// write is all or nothing and nothing depends on how SwiftData runs a batch delete (ADR-0030, ADR-0057 §7).
///
/// The store's files are never swapped: the container stays open for the process and the widget may hold them.
@ModelActor
actor SwiftDataWholeSagaRepository: WholeSagaRepository {
    /// In one actor turn, so no write lands between the reads.
    func readAll() async throws -> StoredSaga? {
        guard let profile = try modelContext.fetch(FetchDescriptor<ProfileRecord>()).first else { return nil }
        let children = try modelContext
            .fetch(FetchDescriptor<ChildRecord>(sortBy: [SortDescriptor(\.order)]))
            .map { try $0.toDomain() }
        let events = try modelContext
            .fetch(FetchDescriptor<ProgressEventRecord>(sortBy: [SortDescriptor(\.date)]))
            .compactMap { $0.toDomain() }
        var outfit = Outfit()
        for record in try modelContext.fetch(FetchDescriptor<OutfitRecord>()) {
            guard let skill = Skill(rawValue: record.skill), let choice = OutfitCoding.decode(record.choice) else { continue }
            outfit.choices[skill] = choice
        }
        return StoredSaga(
            profile: profile.toDomain(children: children), events: events, outfit: outfit, kept: profile.kept
        )
    }

    /// The kept standing is written column by column: `ProfileRecord(profile:)` keeps no gear, which would freeze a saga
    /// from before titles with nothing and take away the gear the old rule earned (ADR-0055 §4).
    func replaceAll(with saga: StoredSaga) async throws {
        try modelContext.saveAllOrNothing {
            try deleteEveryRow()
            let profile = ProfileRecord(profile: saga.profile)
            profile.heldTitleID = saga.kept.titleID
            profile.seenTitleID = saga.kept.seenTitleID
            profile.keptGearIDs = saga.kept.gearIDs
            modelContext.insert(profile)
            for (order, child) in saga.profile.children.enumerated() {
                modelContext.insert(ChildRecord(child: child, order: order))
            }
            for event in saga.events {
                modelContext.insert(ProgressEventRecord(event: event))
            }
            for (skill, choice) in saga.outfit.choices {
                guard let encoded = OutfitCoding.encode(choice) else { continue }
                modelContext.insert(OutfitRecord(skill: skill.rawValue, choice: encoded))
            }
        }
    }

    func eraseAll() async throws {
        try modelContext.saveAllOrNothing { try deleteEveryRow() }
    }

    private func deleteEveryRow() throws {
        try deleteEvery(ProfileRecord.self)
        try deleteEvery(ChildRecord.self)
        try deleteEvery(ProgressEventRecord.self)
        try deleteEvery(OutfitRecord.self)
    }

    private func deleteEvery<Model: PersistentModel>(_: Model.Type) throws {
        for model in try modelContext.fetch(FetchDescriptor<Model>()) {
            modelContext.delete(model)
        }
    }
}
