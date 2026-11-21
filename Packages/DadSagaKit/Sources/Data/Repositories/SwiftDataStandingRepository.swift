import Application
import Domain
import Foundation
import SwiftData

/// `StandingRepository` on the profile row (ADR-0055 §5), so starting over erases it with the saga. Created through
/// `LocalStore`.
@ModelActor
actor SwiftDataStandingRepository: StandingRepository {
    func fetchKept() async throws -> KeptStanding {
        try record()?.kept ?? .fresh
    }

    func keep(titleID: String?, gearIDs: [String]) async throws {
        try modelContext.saveAllOrNothing {
            guard let record = try record() else { return }
            record.heldTitleID = titleID ?? record.heldTitleID
            record.keptGearIDs = gearIDs
        }
    }

    func markSeen(titleID: String) async throws {
        try modelContext.saveAllOrNothing {
            guard let record = try record() else { return }
            record.seenTitleID = titleID
        }
    }

    private func record() throws -> ProfileRecord? {
        try modelContext.fetch(FetchDescriptor<ProfileRecord>()).first
    }
}
