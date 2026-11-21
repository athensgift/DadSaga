import Application
import Foundation
import SwiftData

/// `SagaEraser` backed by SwiftData: every row is fetched and deleted on one context, then saved once, so it is all or
/// nothing and nothing depends on how SwiftData runs a batch delete (ADR-0030).
@ModelActor
actor SwiftDataSagaEraser: SagaEraser {
    func eraseAll() async throws {
        try modelContext.saveAllOrNothing {
            try deleteEvery(ProfileRecord.self)
            try deleteEvery(ChildRecord.self)
            try deleteEvery(ProgressEventRecord.self)
            try deleteEvery(OutfitRecord.self)
        }
    }

    private func deleteEvery<Model: PersistentModel>(_: Model.Type) throws {
        for model in try modelContext.fetch(FetchDescriptor<Model>()) {
            modelContext.delete(model)
        }
    }
}
