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

    /// The saga's store in the folder the app shares with the widget (ADR-0023). Without the App Group a release
    /// build opens nothing: every call throws `SharedContainerError.appGroupUnavailable` (ADR-0048).
    public static func shared(readOnly: Bool = false) -> LocalStore {
        live(directory: { try SharedContainer.directory() }, readOnly: readOnly)
    }

    /// The on-disk store in `directory`. The app opens it read-write; the widget opens it read-only, so only the app
    /// ever writes or migrates it.
    public static func live(in directory: URL, readOnly: Bool = false) -> LocalStore {
        live(directory: { directory }, readOnly: readOnly)
    }

    /// The store in the folder `directory` finds when the store is first opened.
    static func live(directory: @escaping @Sendable () throws -> URL, readOnly: Bool) -> LocalStore {
        LocalStore(connection: StoreConnection(directory: directory, readOnly: readOnly))
    }

    /// A store that is discarded with the process. For tests and previews.
    public static func inMemory() -> LocalStore {
        LocalStore(connection: StoreConnection(directory: nil, readOnly: false))
    }
}
