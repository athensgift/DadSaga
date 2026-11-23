import Application
import Domain
import Foundation
import SwiftData

/// `ProgressRepository` backed by SwiftData.
@ModelActor
actor SwiftDataProgressRepository: ProgressRepository {
    func fetchEvents() async throws -> [ProgressEvent] {
        let descriptor = FetchDescriptor<ProgressEventRecord>(sortBy: [SortDescriptor(\.date)])
        return try modelContext.fetch(descriptor).compactMap { $0.toDomain() }
    }

    /// Read from the rows, not from `fetchEvents`, whose mapping leaves out rows it can't show.
    func referencedPhotoIDs() async throws -> Set<String> {
        Set(try modelContext.fetch(FetchDescriptor<ProgressEventRecord>()).flatMap(\.photoIDs))
    }

    func add(_ event: ProgressEvent) async throws {
        try modelContext.saveAllOrNothing { modelContext.insert(ProgressEventRecord(event: event)) }
    }

    /// Synchronous inside the actor between the check and the save, so no other write can land in between. The check
    /// fetches the row rather than counting: after a rollback, `fetchCount` still counts the undone insert once.
    func addUnlessRecorded(_ event: ProgressEvent) async throws -> Bool {
        let record = ProgressEventRecord(event: event)
        let kind = record.kind
        let contentID = record.contentID
        let childID = event.childID
        let authorID = event.authorID
        // A boss is what a parent does: once per child for each of them. A first is what a child does: once per child,
        // whoever captured it (ADR-0065 §3.3).
        let predicate: Predicate<ProgressEventRecord>
        if case .boss = event.kind {
            predicate = #Predicate<ProgressEventRecord> { record in
                record.kind == kind && record.contentID == contentID && record.childID == childID
                    && record.authorID == authorID
            }
        } else {
            predicate = #Predicate<ProgressEventRecord> { record in
                record.kind == kind && record.contentID == contentID && record.childID == childID
            }
        }
        var existing = FetchDescriptor<ProgressEventRecord>(predicate: predicate)
        existing.fetchLimit = 1
        return try modelContext.saveAllOrNothing {
            guard try modelContext.fetch(existing).isEmpty else { return false }
            modelContext.insert(record)
            return true
        }
    }

    func update(_ event: ProgressEvent) async throws {
        guard let record = try record(id: event.id) else { throw ProgressError.unknownEvent }
        try modelContext.saveAllOrNothing {
            record.date = event.date
            record.note = event.note
            record.photoIDs = event.photoIDs
            record.childID = event.childID
        }
    }

    func delete(id: UUID) async throws {
        guard let record = try record(id: id) else { return }
        try modelContext.saveAllOrNothing { modelContext.delete(record) }
    }

    private func record(id: UUID) throws -> ProgressEventRecord? {
        try modelContext.fetch(FetchDescriptor<ProgressEventRecord>(predicate: #Predicate { $0.eventID == id })).first
    }
}
