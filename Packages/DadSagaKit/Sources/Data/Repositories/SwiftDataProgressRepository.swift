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

    func update(_ event: ProgressEvent) async throws {
        guard let record = try record(id: event.id) else { return }
        record.date = event.date
        record.note = event.note
        record.photoID = event.photoID
        record.childID = event.childID
        try modelContext.save()
    }

    func delete(id: UUID) async throws {
        guard let record = try record(id: id) else { return }
        modelContext.delete(record)
        try modelContext.save()
    }

    func deleteAll() async throws {
        try modelContext.delete(model: ProgressEventRecord.self)
        try modelContext.save()
    }

    private func record(id: UUID) throws -> ProgressEventRecord? {
        try modelContext.fetch(FetchDescriptor<ProgressEventRecord>(predicate: #Predicate { $0.eventID == id })).first
    }
}

actor InMemoryProgressRepository: ProgressRepository {
    private var events: [ProgressEvent] = []

    func fetchEvents() async throws -> [ProgressEvent] {
        events
    }

    func add(_ event: ProgressEvent) async throws {
        events.append(event)
    }

    func update(_ event: ProgressEvent) async throws {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[index] = event
    }

    func delete(id: UUID) async throws {
        events.removeAll { $0.id == id }
    }

    func deleteAll() async throws {
        events = []
    }
}
