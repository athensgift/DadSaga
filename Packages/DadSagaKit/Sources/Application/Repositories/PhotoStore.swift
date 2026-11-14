import Foundation

/// Port for photos of legendary moments. They stay on the device (ADR-0004); only their id is stored with the moment.
public protocol PhotoStore: Sendable {
    /// Stores image data (any common format) and returns its id.
    func save(_ imageData: Data) async throws -> String
    /// `nil` if there is no photo with that id.
    func load(id: String) async -> Data?
    func delete(id: String) async
    /// Wipes every photo. Only the developer reset uses this.
    func deleteAll() async
}
