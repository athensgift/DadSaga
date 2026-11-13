import Application
import Domain
import Foundation
import SwiftData

/// `ProfileRepository` backed by SwiftData. Created through `LocalStore`.
@ModelActor
actor SwiftDataProfileRepository: ProfileRepository {
    func fetchProfile() async throws -> PlayerProfile? {
        try record().map { record in
            PlayerProfile(
                child: Child(name: record.childName, birthDate: record.birthDate),
                heroClassID: record.heroClassID
            )
        }
    }

    func save(_ profile: PlayerProfile) async throws {
        if let record = try record() {
            record.childName = profile.child.name
            record.birthDate = profile.child.birthDate
            record.heroClassID = profile.heroClassID
        } else {
            modelContext.insert(
                ProfileRecord(
                    childName: profile.child.name,
                    birthDate: profile.child.birthDate,
                    heroClassID: profile.heroClassID
                )
            )
        }
        try modelContext.save()
    }

    func deleteProfile() async throws {
        try modelContext.delete(model: ProfileRecord.self)
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
