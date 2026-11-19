import Application
import Domain
import Foundation
import SwiftData

/// `ProfileRepository` backed by SwiftData. Created through `LocalStore`.
@ModelActor
actor SwiftDataProfileRepository: ProfileRepository {
    func fetchProfile() async throws -> PlayerProfile? {
        guard let record = try record() else { return nil }
        let children = try modelContext
            .fetch(FetchDescriptor<ChildRecord>(sortBy: [SortDescriptor(\.order)]))
            .map { $0.toDomain() }
        return PlayerProfile(
            children: children,
            heroClassID: record.heroClassID,
            dadSkinTone: SkinTone(rawValue: record.dadSkinTone) ?? .mediumLight
        )
    }

    /// Updates the stored profile and family in place: rows keep their identity, which sync will need (ADR-0026).
    /// Children are matched by id, so their progress stays linked; removed children and duplicate rows go.
    func save(_ profile: PlayerProfile) async throws {
        let profiles = try modelContext.fetch(FetchDescriptor<ProfileRecord>())
        if let record = profiles.first {
            record.heroClassID = profile.heroClassID
            record.dadSkinTone = profile.dadSkinTone.rawValue
        } else {
            modelContext.insert(ProfileRecord(heroClassID: profile.heroClassID, dadSkinTone: profile.dadSkinTone.rawValue))
        }
        profiles.dropFirst().forEach(modelContext.delete)

        var stored: [UUID: ChildRecord] = [:]
        for record in try modelContext.fetch(FetchDescriptor<ChildRecord>()) {
            if stored[record.childID] == nil { stored[record.childID] = record } else { modelContext.delete(record) }
        }
        for (order, child) in profile.children.enumerated() {
            if let record = stored.removeValue(forKey: child.id) {
                record.update(from: child, order: order)
            } else {
                modelContext.insert(ChildRecord(child: child, order: order))
            }
        }
        stored.values.forEach(modelContext.delete)
        try modelContext.save()
    }

    private func record() throws -> ProfileRecord? {
        try modelContext.fetch(FetchDescriptor<ProfileRecord>()).first
    }
}
