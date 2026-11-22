import Foundation

/// Port for photos of legendary moments. They stay on the device (ADR-0004); only their id is stored with the moment.
public protocol PhotoStore: Sendable {
    /// Stores image data (any common format) and returns its id.
    func save(_ imageData: Data) async throws -> String
    /// A JPEG copy whose longest side is at most `maxPixelSize`, decoded straight from the file so the full photo never
    /// sits in memory.
    /// `nil` if there is no photo with that id or it cannot be read.
    func thumbnail(id: String, maxPixelSize: Int) async -> Data?
    /// The photo's file as stored, byte for byte, for a copy of the saga (ADR-0057 §6).
    func storedData(id: String) async throws -> Data
    /// Stores a photo from a copy of the saga as it is, never re-encoded (ADR-0042 §1), under a new id. Throws when the
    /// data isn't a JPEG.
    func adopt(_ jpeg: Data) async throws -> String
    func delete(id: String) async
    /// Wipes every photo. Only starting over uses this.
    func deleteAll() async
    /// Every photo file there is, with when it was written. Throws if the folder can't be read, so a sweep that can't
    /// see the files deletes none (ADR-0048 §6).
    func storedPhotos() async throws -> [StoredPhoto]
}

/// A photo file and when it was written; `nil` when the date can't be read.
public struct StoredPhoto: Hashable, Sendable {
    public let id: String
    public let savedAt: Date?

    public init(id: String, savedAt: Date?) {
        self.id = id
        self.savedAt = savedAt
    }
}
