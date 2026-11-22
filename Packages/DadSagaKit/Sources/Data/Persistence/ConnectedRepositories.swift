import Application
import Domain
import Foundation

/// The repositories `LocalStore` hands out. Each call opens the store first if it is not open yet (ADR-0026).
///
/// Every method is `@concurrent`: a `@ModelActor` runs a call on the thread that enqueued it, so a screen calling it
/// from the main actor would fetch and save on the main thread. Leaving the caller's actor here keeps the store's work
/// off it, whatever the compiler's default for `nonisolated async` functions (ADR-0034).
struct ConnectedProfileRepository: ProfileRepository {
    let connection: StoreConnection

    @concurrent func fetchProfile() async throws -> PlayerProfile? { try await connection.open().profiles.fetchProfile() }
    @concurrent func save(_ profile: PlayerProfile) async throws { try await connection.open().profiles.save(profile) }
}

struct ConnectedProgressRepository: ProgressRepository {
    let connection: StoreConnection

    @concurrent func fetchEvents() async throws -> [ProgressEvent] { try await connection.open().progress.fetchEvents() }
    @concurrent func referencedPhotoIDs() async throws -> Set<String> {
        try await connection.open().progress.referencedPhotoIDs()
    }
    @concurrent func add(_ event: ProgressEvent) async throws { try await connection.open().progress.add(event) }
    @concurrent func addUnlessRecorded(_ event: ProgressEvent) async throws -> Bool {
        try await connection.open().progress.addUnlessRecorded(event)
    }
    @concurrent func update(_ event: ProgressEvent) async throws { try await connection.open().progress.update(event) }
    @concurrent func delete(id: UUID) async throws { try await connection.open().progress.delete(id: id) }
}

struct ConnectedOutfitRepository: OutfitRepository {
    let connection: StoreConnection

    @concurrent func fetchOutfit() async throws -> Outfit { try await connection.open().outfit.fetchOutfit() }
    @concurrent func setChoice(_ choice: OutfitChoice, for skill: Skill) async throws -> Outfit {
        try await connection.open().outfit.setChoice(choice, for: skill)
    }
}

struct ConnectedStandingRepository: StandingRepository {
    let connection: StoreConnection

    @concurrent func fetchKept() async throws -> KeptStanding { try await connection.open().standing.fetchKept() }
    @concurrent func keep(titleID: String) async throws {
        try await connection.open().standing.keep(titleID: titleID)
    }
    @concurrent func markSeen(titleID: String) async throws {
        try await connection.open().standing.markSeen(titleID: titleID)
    }
}

struct ConnectedWholeSagaRepository: WholeSagaRepository {
    let connection: StoreConnection

    @concurrent func readAll() async throws -> StoredSaga? { try await connection.open().wholeSaga.readAll() }
    @concurrent func replaceAll(with saga: StoredSaga) async throws {
        try await connection.open().wholeSaga.replaceAll(with: saga)
    }
    @concurrent func eraseAll() async throws { try await connection.open().wholeSaga.eraseAll() }
}
