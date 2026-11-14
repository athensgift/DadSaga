import Application
import Domain
import Foundation
import SwiftData

/// `ProfileRepository` backed by SwiftData. Created through `LocalStore`.
@ModelActor
actor SwiftDataProfileRepository: ProfileRepository {
    func fetchProfile() async throws -> PlayerProfile? {
        try LegacyProfileMigration.run(in: modelContext)
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

    /// Replaces the stored profile and family. Children keep their ids, so their progress stays linked.
    func save(_ profile: PlayerProfile) async throws {
        let first = profile.children.first
        if let record = try record() {
            record.childName = first?.name ?? ""
            record.birthDate = first?.birthDate ?? .now
            record.heroClassID = profile.heroClassID
            record.dadSkinTone = profile.dadSkinTone.rawValue
        } else {
            modelContext.insert(
                ProfileRecord(
                    childName: first?.name ?? "",
                    birthDate: first?.birthDate ?? .now,
                    heroClassID: profile.heroClassID,
                    dadSkinTone: profile.dadSkinTone.rawValue
                )
            )
        }
        try modelContext.delete(model: ChildRecord.self)
        for (order, child) in profile.children.enumerated() {
            modelContext.insert(ChildRecord(child: child, order: order))
        }
        try modelContext.save()
    }

    func deleteProfile() async throws {
        try modelContext.delete(model: ProfileRecord.self)
        try modelContext.delete(model: ChildRecord.self)
        try modelContext.save()
    }

    private func record() throws -> ProfileRecord? {
        try modelContext.fetch(FetchDescriptor<ProfileRecord>()).first
    }
}

/// Keeps the profile only while the app runs. See `LocalStore.sessionOnly()`.
actor InMemoryProfileRepository: ProfileRepository {
    private var profile: PlayerProfile?

    func fetchProfile() async throws -> PlayerProfile? {
        profile
    }

    func save(_ profile: PlayerProfile) async throws {
        self.profile = profile
    }

    func deleteProfile() async throws {
        profile = nil
    }
}
