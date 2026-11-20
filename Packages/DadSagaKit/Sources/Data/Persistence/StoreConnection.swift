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
        let eraser: SwiftDataSagaEraser
    }

    private static let logger = Logger(subsystem: "DadSaga", category: "store")

    /// The version the app reads and writes; older stores reach it through `DadSagaMigrationPlan`.
    static var schema: Schema { Schema(versionedSchema: CurrentSchema.self) }

    private let configuration: ModelConfiguration
    /// Created before opening an on-disk store.
    private let directory: URL?
    private var opened: Repositories?

    init(configuration: ModelConfiguration, directory: URL?) {
        self.configuration = configuration
        self.directory = directory
    }

    /// Synchronous inside the actor, so two callers can never open the store twice.
    func open() throws -> Repositories {
        if let opened { return opened }
        do {
            if let directory { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
            let container = try ModelContainer(
                for: Self.schema,
                migrationPlan: DadSagaMigrationPlan.self,
                configurations: [configuration]
            )
            let repositories = Repositories(
                profiles: SwiftDataProfileRepository(modelContainer: container),
                progress: SwiftDataProgressRepository(modelContainer: container),
                outfit: SwiftDataOutfitRepository(modelContainer: container),
                eraser: SwiftDataSagaEraser(modelContainer: container)
            )
            opened = repositories
            return repositories
        } catch {
            Self.logger.error("The store could not be opened: \(String(describing: error), privacy: .public)")
            throw error
        }
    }
}
