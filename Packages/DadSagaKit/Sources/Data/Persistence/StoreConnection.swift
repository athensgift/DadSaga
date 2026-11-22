import Foundation
import os
import SwiftData

/// Opens the SwiftData store on first use, off the main actor, and keeps it open (ADR-0026). If opening fails, that
/// call throws and the next one tries again. Nothing is created in its place, deleted or reset.
actor StoreConnection {
    struct Repositories: Sendable {
        let profiles: SwiftDataProfileRepository
        let progress: SwiftDataProgressRepository
        let outfit: SwiftDataOutfitRepository
        let standing: SwiftDataStandingRepository
        let eraser: SwiftDataSagaEraser
    }

    private static let logger = Logger(subsystem: "DadSaga", category: "store")

    /// The version the app reads and writes; older stores reach it through `DadSagaMigrationPlan`.
    static var schema: Schema { Schema(versionedSchema: CurrentSchema.self) }

    /// The store's folder, found and created when the store is opened; `nil` keeps the store in memory.
    private let directory: (@Sendable () throws -> URL)?
    private let readOnly: Bool
    private var opened: Repositories?

    init(directory: (@Sendable () throws -> URL)?, readOnly: Bool) {
        self.directory = directory
        self.readOnly = readOnly
    }

    /// Synchronous inside the actor, so two callers can never open the store twice.
    func open() throws -> Repositories {
        if let opened { return opened }
        do {
            // Only the app migrates (ADR-0026). Read-only, no stage may run: a stage's own work (V5 → V6 fills birth days
            // before the column goes) would write to a store the widget must leave as it found it (ADR-0053 §8). An
            // older store then fails to open, untouched, until the app has migrated it.
            let container = try ModelContainer(
                for: Self.schema,
                migrationPlan: readOnly ? nil : DadSagaMigrationPlan.self,
                configurations: [configuration()]
            )
            let repositories = Repositories(
                profiles: SwiftDataProfileRepository(modelContainer: container),
                progress: SwiftDataProgressRepository(modelContainer: container),
                outfit: SwiftDataOutfitRepository(modelContainer: container),
                standing: SwiftDataStandingRepository(modelContainer: container),
                eraser: SwiftDataSagaEraser(modelContainer: container)
            )
            opened = repositories
            return repositories
        } catch {
            Self.logger.error("The store could not be opened: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    /// Named explicitly, so SwiftData never picks a location on its own (ADR-0023). Never synced: sync will be its
    /// own decision, not a side effect of an iCloud entitlement.
    private func configuration() throws -> ModelConfiguration {
        guard let directory else {
            return ModelConfiguration(
                schema: Self.schema,
                isStoredInMemoryOnly: true,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
        }
        let folder = try directory()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return ModelConfiguration(
            schema: Self.schema,
            url: folder.appending(path: "DadSaga.store"),
            allowsSave: !readOnly,
            cloudKitDatabase: .none
        )
    }
}
