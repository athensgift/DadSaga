import Application
import SwiftData

/// The on-device database. One SwiftData container shared by every repository that persists player data (ADR-0004).
public struct LocalStore: Sendable {
    public let profiles: any ProfileRepository
    public let progress: any ProgressRepository

    /// The on-disk store used by the app.
    public static func live() throws -> LocalStore {
        try make(inMemory: false)
    }

    /// A store that is discarded with the process. For tests and previews.
    public static func inMemory() throws -> LocalStore {
        try make(inMemory: true)
    }

    /// Keeps data only while the app runs. Last resort if the on-disk store cannot be opened.
    public static func sessionOnly() -> LocalStore {
        LocalStore(profiles: InMemoryProfileRepository(), progress: InMemoryProgressRepository())
    }

    private static func make(inMemory: Bool) throws -> LocalStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(for: ProfileRecord.self, ProgressEventRecord.self, configurations: configuration)
        return LocalStore(
            profiles: SwiftDataProfileRepository(modelContainer: container),
            progress: SwiftDataProgressRepository(modelContainer: container)
        )
    }
}
