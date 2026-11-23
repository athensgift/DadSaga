import Foundation
import SwiftData

/// Opens `Sync.store`, sync's own store beside the saga's (ADR-0065 §5), and keeps it open. It is created when iCloud
/// is first turned on, and by nothing else: until then no file exists, and the widget never opens it. Never synced by
/// SwiftData itself.
actor SyncStoreConnection {
    static let fileName = "Sync.store"
    static var schema: Schema { Schema(versionedSchema: CurrentSyncSchema.self) }

    /// The saga's folder, found when the store is opened.
    private let directory: @Sendable () throws -> URL
    private var opened: SyncLedger?

    init(directory: @escaping @Sendable () throws -> URL) {
        self.directory = directory
    }

    /// The ledger over `Sync.store`. `nil` when the file isn't there and `creating` is false, so asking where sync
    /// stands with iCloud never turned on creates nothing. Synchronous inside the actor, so two callers can never
    /// open the store twice.
    func open(creating: Bool) throws -> SyncLedger? {
        if let opened { return opened }
        let url = try directory().appending(path: Self.fileName)
        guard creating || FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try make()
    }

    /// The ledger, its file created when iCloud is first turned on.
    func make() throws -> SyncLedger {
        if let opened { return opened }
        let folder = try directory()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Named explicitly, so SwiftData never picks a location on its own.
        let container = try ModelContainer(
            for: Self.schema,
            migrationPlan: SyncMigrationPlan.self,
            configurations: [ModelConfiguration(
                schema: Self.schema, url: folder.appending(path: Self.fileName), allowsSave: true, cloudKitDatabase: .none
            )]
        )
        let ledger = SyncLedger(modelContainer: container)
        opened = ledger
        return ledger
    }
}
