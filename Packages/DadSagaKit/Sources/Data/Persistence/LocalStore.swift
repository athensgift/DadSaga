import Application
import Foundation
import SwiftData

/// The on-device database. One SwiftData container shared by every repository that persists player data (ADR-0004).
public struct LocalStore: Sendable {
    public let profiles: any ProfileRepository
    public let progress: any ProgressRepository
    public let outfit: any OutfitRepository

    /// The on-disk store in `directory`, named explicitly so SwiftData never picks a location on its own (ADR-0023).
    /// The app opens it read-write; the widget opens it read-only, so only the app ever writes or migrates it.
    public static func live(in directory: URL, readOnly: Bool = false) throws -> LocalStore {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "DadSaga.store")
        return try make(ModelConfiguration(url: url, allowsSave: !readOnly))
    }

    /// A store that is discarded with the process. For tests and previews.
    public static func inMemory() throws -> LocalStore {
        try make(ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// Keeps data only while the app runs. Last resort if the on-disk store cannot be opened.
    public static func sessionOnly() -> LocalStore {
        LocalStore(
            profiles: InMemoryProfileRepository(),
            progress: InMemoryProgressRepository(),
            outfit: InMemoryOutfitRepository()
        )
    }

    private static func make(_ configuration: ModelConfiguration) throws -> LocalStore {
        let container = try ModelContainer(
            for: ProfileRecord.self, ChildRecord.self, ProgressEventRecord.self, OutfitRecord.self,
            configurations: configuration
        )
        return LocalStore(
            profiles: SwiftDataProfileRepository(modelContainer: container),
            progress: SwiftDataProgressRepository(modelContainer: container),
            outfit: SwiftDataOutfitRepository(modelContainer: container)
        )
    }
}
