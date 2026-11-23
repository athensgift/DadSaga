import Application
import Domain
import Foundation
import SwiftData

/// `StandingRepository` on the profile row (ADR-0055 §5), so starting over erases it with the saga. Created through
/// `LocalStore`.
actor SwiftDataStandingRepository: StandingRepository, SagaStoreActor {
    nonisolated let modelExecutor: any ModelExecutor
    nonisolated let modelContainer: ModelContainer

    init(queue: DefaultSerialModelExecutor, container: ModelContainer) {
        modelExecutor = queue
        modelContainer = container
    }

    func fetchKept() async throws -> KeptStanding {
        try record()?.kept ?? KeptStanding()
    }

    /// The higher of the title kept and `titleID`, compared in this turn with the row as stored (ADR-0068 §3).
    func keep(titleID: String, catalog: ContentCatalog) async throws {
        try modelContext.saveAllOrNothing {
            guard let record = try record() else { return }
            record.update(\.heldTitleID, to: record.kept.keeping(titleID: titleID, catalog: catalog).titleID)
        }
    }

    func markSeen(titleID: String) async throws {
        try modelContext.saveAllOrNothing {
            guard let record = try record() else { return }
            record.update(\.seenTitleID, to: titleID)
        }
    }

    private func record() throws -> ProfileRecord? {
        try modelContext.fetch(FetchDescriptor<ProfileRecord>()).first
    }
}
