import Domain
import Foundation

/// Port for the log of things the dad has done. The game itself only ever adds events (ADR-0006);
/// `update` and `delete` exist for the dad correcting his own entries (ADR-0021).
public protocol ProgressRepository: Sendable {
    func fetchEvents() async throws -> [ProgressEvent]
    func add(_ event: ProgressEvent) async throws
    /// Adds the event unless the same child already has one for the same content, checked and stored in one step so two
    /// saves at the same moment can never both land. Returns whether it was added.
    func addUnlessRecorded(_ event: ProgressEvent) async throws -> Bool
    /// Replaces the stored event that has the same id. Does nothing if there is none.
    func update(_ event: ProgressEvent) async throws
    func delete(id: UUID) async throws
    /// Wipes the log. Only the developer reset uses this.
    func deleteAll() async throws
}
