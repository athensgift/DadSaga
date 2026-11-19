import Application
import Foundation
import SwiftData

/// The on-device database. One SwiftData container shared by every repository that persists player data (ADR-0004).
/// It is versioned and opened on first use; if it cannot be opened, every call throws and nothing takes its place
/// (ADR-0026).
public struct LocalStore: Sendable {
    public let profiles: any ProfileRepository
    public let progress: any ProgressRepository
    public let outfit: any OutfitRepository
    /// Starting over: the whole saga in one write.
    public let eraser: any SagaEraser

    private init(connection: StoreConnection) {
        profiles = ConnectedProfileRepository(connection: connection)
        progress = ConnectedProgressRepository(connection: connection)
        outfit = ConnectedOutfitRepository(connection: connection)
        eraser = ConnectedSagaEraser(connection: connection)
    }

    /// The on-disk store in `directory`, named explicitly so SwiftData never picks a location on its own (ADR-0023).
    /// The app opens it read-write; the widget opens it read-only, so only the app ever writes or migrates it.
    /// Never synced: sync will be its own decision, not a side effect of an iCloud entitlement.
    public static func live(in directory: URL, readOnly: Bool = false) -> LocalStore {
        live(in: directory, readOnly: readOnly, versions: .dadSaga)
    }

    static func live(in directory: URL, readOnly: Bool, versions: StoreVersions) -> LocalStore {
        let configuration = ModelConfiguration(
            schema: versions.current,
            url: directory.appending(path: "DadSaga.store"),
            allowsSave: !readOnly,
            cloudKitDatabase: .none
        )
        return LocalStore(
            connection: StoreConnection(configuration: configuration, versions: versions, directory: directory)
        )
    }

    /// A store that is discarded with the process. For tests and previews.
    public static func inMemory() -> LocalStore {
        let versions = StoreVersions.dadSaga
        let configuration = ModelConfiguration(
            schema: versions.current,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return LocalStore(connection: StoreConnection(configuration: configuration, versions: versions, directory: nil))
    }
}
