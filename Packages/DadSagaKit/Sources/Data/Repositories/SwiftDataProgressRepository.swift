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

    func deleteAll() async throws {
        try modelContext.delete(model: ProgressEventRecord.self)
        try modelContext.save()
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

    func deleteAll() async throws {
        events = []
    }
}
