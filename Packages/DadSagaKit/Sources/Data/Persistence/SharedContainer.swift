import Foundation

/// The saga's folder cannot be found: the build has no App Group. In a release build nothing takes its place, so the
/// app shows its calm "couldn't open" screen instead of a new, empty saga (ADR-0048).
public enum SharedContainerError: Error, Equatable {
    case appGroupUnavailable
}

/// The folder the app and the widget share through an App Group (ADR-0023): the database and the moment photos.
enum SharedContainer {
    static let appGroupID = "group.com.athinodoros.dadsaga"

    /// `Library/Application Support` inside the App Group container. Without the entitlement, a debug build falls
    /// back to the process's own Application Support (the widget then finds no data); a release build throws.
    static func directory(fileManager: FileManager = .default) throws -> URL {
        try directory(
            group: fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID),
            fallback: debugFallback(fileManager: fileManager)
        )
    }

    static func directory(group: URL?, fallback: URL?) throws -> URL {
        if let group {
            return group.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        }
        guard let fallback else { throw SharedContainerError.appGroupUnavailable }
        return fallback
    }

    private static func debugFallback(fileManager: FileManager) -> URL? {
        #if DEBUG
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        #else
        nil
        #endif
    }
}
