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

    func add(_ event: ProgressEvent) async throws {
        modelContext.insert(ProgressEventRecord(event: event))
        try modelContext.save()
    }

    /// Synchronous inside the actor between the check and the save, so no other write can land in between.
    func addUnlessRecorded(_ event: ProgressEvent) async throws -> Bool {
        let record = ProgressEventRecord(event: event)
        let kind = record.kind
        let contentID = record.contentID
        let childID: UUID? = event.childID
        var existing = FetchDescriptor<ProgressEventRecord>(
            predicate: #Predicate { $0.kind == kind && $0.contentID == contentID && $0.childID == childID }
        )
        existing.fetchLimit = 1
        guard try modelContext.fetchCount(existing) == 0 else { return false }
        modelContext.insert(record)
        try modelContext.save()
        return true
    }

    func update(_ event: ProgressEvent) async throws {
        guard let record = try record(id: event.id) else { return }
        record.date = event.date
        record.note = event.note
        record.photoIDs = event.photoIDs
        record.childID = event.childID
        try modelContext.save()
    }

    func delete(id: UUID) async throws {
        guard let record = try record(id: id) else { return }
        modelContext.delete(record)
        try modelContext.save()
    }

    private func record(id: UUID) throws -> ProgressEventRecord? {
        try modelContext.fetch(FetchDescriptor<ProgressEventRecord>(predicate: #Predicate { $0.eventID == id })).first
    }
}
