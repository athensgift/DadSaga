import Foundation
import SwiftData
@testable import Data

/// How many rows of `Model` the store file at `url` holds, read through a container of its own, so no repository's
/// context (or a fetch that keeps one row per id) can hide a duplicate.
func storedRowCount<Model: PersistentModel>(_: Model.Type, at url: URL) throws -> Int {
    let container = try ModelContainer(
        for: Schema(versionedSchema: CurrentSchema.self),
        migrationPlan: DadSagaMigrationPlan.self,
        configurations: [ModelConfiguration(url: url, cloudKitDatabase: .none)]
    )
    return try ModelContext(container).fetchCount(FetchDescriptor<Model>())
}
