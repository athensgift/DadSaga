import Foundation

/// The folder the app and the widget share through an App Group (ADR-0023): the database and the moment photos.
public enum SharedContainer {
    public static let appGroupID = "group.com.athinodoros.dadsaga"

    /// `Library/Application Support` inside the App Group container. Without the entitlement (a build signed without
    /// it) this is the process's own Application Support: the app still works, and the widget finds no data.
    public static func directory(fileManager: FileManager = .default) -> URL {
        if let group = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return group.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        }
        return fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
    }
}
