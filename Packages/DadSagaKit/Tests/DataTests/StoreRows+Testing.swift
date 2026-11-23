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

/// One row's change in the store's history: what happened, to which model, and for an update the columns it lists.
struct RowChange: Hashable, CustomStringConvertible {
    enum Kind: Hashable { case insert, update, delete }
    let kind: Kind
    let model: String
    let columns: Set<AnyKeyPath>

    static func update<Model: PersistentModel>(_: Model.Type, _ columns: [PartialKeyPath<Model>]) -> RowChange {
        RowChange(kind: .update, model: String(describing: Model.self), columns: Set(columns.map { $0 as AnyKeyPath }))
    }

    static func insert<Model: PersistentModel>(_: Model.Type) -> RowChange {
        RowChange(kind: .insert, model: String(describing: Model.self), columns: [])
    }

    static func delete<Model: PersistentModel>(_: Model.Type) -> RowChange {
        RowChange(kind: .delete, model: String(describing: Model.self), columns: [])
    }

    var description: String { "\(kind) \(model) \(columns.map { "\($0)" }.sorted())" }
}

/// The store file's history, read through a container of its own: each transaction's row changes.
func storeHistory(at url: URL) throws -> [[RowChange]] {
    let container = try ModelContainer(
        for: Schema(versionedSchema: CurrentSchema.self),
        migrationPlan: DadSagaMigrationPlan.self,
        configurations: [ModelConfiguration(url: url, cloudKitDatabase: .none)]
    )
    return try ModelContext(container).fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).map { transaction in
        transaction.changes.map { change in
            switch change {
            case .insert(let insert): rowChange(insert)
            case .update(let update): rowChange(update)
            case .delete(let delete): rowChange(delete)
            @unknown default: RowChange(kind: .update, model: "unknown", columns: [])
            }
        }
    }
}

private func rowChange<Change: HistoryInsert>(_: Change) -> RowChange {
    RowChange(kind: .insert, model: String(describing: Change.Model.self), columns: [])
}

private func rowChange<Change: HistoryUpdate>(_ update: Change) -> RowChange {
    RowChange(
        kind: .update, model: String(describing: Change.Model.self),
        columns: Set(update.updatedAttributes.map { $0 as AnyKeyPath })
    )
}

private func rowChange<Change: HistoryDelete>(_: Change) -> RowChange {
    RowChange(kind: .delete, model: String(describing: Change.Model.self), columns: [])
}
