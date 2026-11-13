import Application
import Domain
import Foundation
import SwiftData

/// `ProfileRepository` backed by SwiftData. The store stays on the device (ADR-0004).
@ModelActor
public actor SwiftDataProfileRepository: ProfileRepository {
    /// The on-disk store used by the app.
    public static func live() throws -> SwiftDataProfileRepository {
        try make(inMemory: false)
    }

    /// A store that is discarded with the process. For tests and previews.
    public static func inMemory() throws -> SwiftDataProfileRepository {
        try make(inMemory: true)
    }

    private static func make(inMemory: Bool) throws -> SwiftDataProfileRepository {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(for: ProfileRecord.self, configurations: configuration)
        return SwiftDataProfileRepository(modelContainer: container)
    }

    public func fetchProfile() async throws -> PlayerProfile? {
        try record().map { record in
            PlayerProfile(
                child: Child(name: record.childName, birthDate: record.birthDate),
                heroClassID: record.heroClassID
            )
        }
    }

    public func save(_ profile: PlayerProfile) async throws {
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

    public func deleteProfile() async throws {
        try modelContext.delete(model: ProfileRecord.self)
        try modelContext.save()
    }

    private func record() throws -> ProfileRecord? {
        try modelContext.fetch(FetchDescriptor<ProfileRecord>()).first
    }
}

/// Keeps the profile only while the app runs. Last-resort fallback if the on-disk store cannot be opened.
public actor InMemoryProfileRepository: ProfileRepository {
    private var profile: PlayerProfile?

    public init() {}

    public func fetchProfile() async throws -> PlayerProfile? {
        profile
    }

    public func save(_ profile: PlayerProfile) async throws {
        self.profile = profile
    }

    public func deleteProfile() async throws {
        profile = nil
    }
}
