import Application
import Domain
import Foundation
import SwiftData

/// `ProfileRepository` backed by SwiftData. Created through `LocalStore`.
@ModelActor
actor SwiftDataProfileRepository: ProfileRepository {
    /// The family only: a child removed from it is never read here (ADR-0065 §4).
    func fetchProfile() async throws -> PlayerProfile? {
        guard let record = try record() else { return nil }
        let children = try modelContext
            .fetch(FetchDescriptor<ChildRecord>(
                predicate: #Predicate { $0.isRemoved == false }, sortBy: [SortDescriptor(\.order)]
            ))
            .map { try $0.toDomain() }
        return record.toDomain(children: children)
    }

    /// Updates the stored profile and family in place: rows keep their identity, which sync will need (ADR-0026).
    /// The stored profile keeps its id; one is inserted, with `profile.id`, only when none is stored. Children are
    /// matched by id, so their progress stays linked; a family child left out goes. A child removed from the family is
    /// left as it is (ADR-0065 §5), and no id the store holds is inserted again. All or nothing: the fetches come
    /// between the changes, so the whole body is inside.
    func save(_ profile: PlayerProfile) async throws {
        try modelContext.saveAllOrNothing {
            let profiles = try modelContext.fetch(FetchDescriptor<ProfileRecord>())
            if let record = profiles.first {
                record.update(from: profile)
            } else {
                modelContext.insert(ProfileRecord(profile: profile))
            }
            // One player per iPhone (ADR-0065 §5): `#Unique` keeps one row per id, not one row.
            profiles.dropFirst().forEach(modelContext.delete)

            var stored: [UUID: ChildRecord] = [:]
            for record in try modelContext.fetch(FetchDescriptor<ChildRecord>()) {
                stored[record.childID] = record
            }
            for (order, child) in profile.children.enumerated() {
                if let record = stored.removeValue(forKey: child.id) {
                    // Only bringing a child back changes a removed row (ADR-0065 §4), and nothing does that yet.
                    guard !record.isRemoved else { continue }
                    record.update(from: child, order: order)
                } else {
                    modelContext.insert(ChildRecord(child: child, order: order, isRemoved: false))
                }
            }
            stored.values.filter { !$0.isRemoved }.forEach(modelContext.delete)
        }
    }

    private func record() throws -> ProfileRecord? {
        try modelContext.fetch(FetchDescriptor<ProfileRecord>()).first
    }
}
