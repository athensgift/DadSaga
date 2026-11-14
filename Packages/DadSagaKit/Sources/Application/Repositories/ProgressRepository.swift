import Domain

import Foundation

/// Port for the log of things the dad has done. The game only ever adds events (ADR-0006: nothing is lost);
/// `update` and `delete` exist for the dad correcting a legendary moment he captured himself.
public protocol ProgressRepository: Sendable {
    func fetchEvents() async throws -> [ProgressEvent]
    func add(_ event: ProgressEvent) async throws
    /// Replaces the stored event that has the same id. Does nothing if there is none.
    func update(_ event: ProgressEvent) async throws
    func delete(id: UUID) async throws
    /// Wipes the log. Only the developer reset uses this.
    func deleteAll() async throws
}
