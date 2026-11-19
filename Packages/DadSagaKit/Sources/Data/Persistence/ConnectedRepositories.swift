import Application
import Domain
import Foundation

/// The repositories `LocalStore` hands out. Each call opens the store first if it is not open yet (ADR-0026).
struct ConnectedProfileRepository: ProfileRepository {
    let connection: StoreConnection

    func fetchProfile() async throws -> PlayerProfile? { try await connection.open().profiles.fetchProfile() }
    func save(_ profile: PlayerProfile) async throws { try await connection.open().profiles.save(profile) }
    func deleteProfile() async throws { try await connection.open().profiles.deleteProfile() }
}

struct ConnectedProgressRepository: ProgressRepository {
    let connection: StoreConnection

    func fetchEvents() async throws -> [ProgressEvent] { try await connection.open().progress.fetchEvents() }
    func add(_ event: ProgressEvent) async throws { try await connection.open().progress.add(event) }
    func addUnlessRecorded(_ event: ProgressEvent) async throws -> Bool {
        try await connection.open().progress.addUnlessRecorded(event)
    }
    func update(_ event: ProgressEvent) async throws { try await connection.open().progress.update(event) }
    func delete(id: UUID) async throws { try await connection.open().progress.delete(id: id) }
    func deleteAll() async throws { try await connection.open().progress.deleteAll() }
}

struct ConnectedOutfitRepository: OutfitRepository {
    let connection: StoreConnection

    func fetchOutfit() async throws -> Outfit { try await connection.open().outfit.fetchOutfit() }
    func setChoice(_ choice: OutfitChoice, for skill: Skill) async throws -> Outfit {
        try await connection.open().outfit.setChoice(choice, for: skill)
    }
    func deleteAll() async throws { try await connection.open().outfit.deleteAll() }
}
