import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// The saga store has one queue (ADR-0068): its repositories and the change feed share one context, so one write runs
/// at a time, each reads every row as last saved, and a save carries only its own turn's changes and author. SwiftData
/// documents none of this for actors that share an executor, so it is pinned on a store on disk.
@Suite("One queue for the saga store", .serialized)
struct SagaStoreQueueTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-queue-" + UUID().uuidString)
    var storeURL: URL { directory.appending(path: "DadSaga.store") }
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    func onboarded() async throws -> (store: LocalStore, entry: ProgressEvent) {
        let store = LocalStore.live(in: directory)
        try await store.profiles.create(PlayerProfile(
            children: [lena, nikos], heroClassID: "h-cool",
            dadAppearance: DadAppearance(hair: .curly, hairColor: .black, beard: .none, glasses: .none)
        ))
        let entry = ProgressEvent(kind: .quest(id: "q1"), childID: lena.id, date: .now, note: "πρώτο")
        try await store.progress.add(entry)
        return (store, entry)
    }

    @Test("Given a restore saved under sync, when the dad edits right after, then only the restore carries the author")
    func theAuthorIsForOneSave() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let (store, _) = try await onboarded()
        let feed = try await store.connection.open().feed
        let before = try await feed.latestToken()
        let saga = try #require(try await store.wholeSaga.readAll())

        try await store.wholeSaga.replaceAll(with: saga)
        try await store.profiles.save(HeroEdit(beard: .full))

        #expect(try storeAuthors(at: storeURL).suffix(2) == ["sync", nil])
        #expect(try await feed.read(after: before) == .changes(
            [.save(.hero(.testDad), fields: ["beard"])], through: try await feed.latestToken()
        ))
    }

    @Test("Given a write under sync whose changes throw, when the next write saves, then it carries no author")
    func aFailedSyncSavePutsTheAuthorBack() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let container = try ModelContainer(
            for: Schema(versionedSchema: CurrentSchema.self), migrationPlan: DadSagaMigrationPlan.self,
            configurations: [ModelConfiguration(url: storeURL, cloudKitDatabase: .none)]
        )
        let context = ModelContext(container)
        struct Refused: Error {}

        #expect(throws: Refused.self) {
            try context.saveAllOrNothing(as: .sync) {
                context.insert(OutfitRecord(skill: "care", choice: "hidden"))
                throw Refused()
            }
        }
        try context.saveAllOrNothing { context.insert(OutfitRecord(skill: "play", choice: "hidden")) }
        try context.saveAllOrNothing(as: .sync) { context.insert(OutfitRecord(skill: "patience", choice: "hidden")) }
        try context.saveAllOrNothing { context.insert(OutfitRecord(skill: "resilience", choice: "hidden")) }

        #expect(context.author == nil)
        #expect(try storeAuthors(at: storeURL) == [nil, "sync", nil])
        #expect(try context.fetch(FetchDescriptor<OutfitRecord>()).map(\.skill).sorted() == ["patience", "play", "resilience"])
    }

    @Test("Given every repository has read the saga, when each row is changed through one, then every other reads the change")
    func everyRepositoryReadsWhatAnotherWrote() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let (store, entry) = try await onboarded()
        _ = try await store.outfit.setChoice(.hidden, for: .care)
        // Every repository loads every row it reads.
        _ = try await store.wholeSaga.readAll()
        _ = try await store.profiles.fetchProfile()
        _ = try await store.progress.fetchEvents()
        _ = try await store.outfit.fetchOutfit()
        _ = try await store.standing.fetchKept()
        var renamed = lena
        renamed.name = "Ελένη"
        let edited = ProgressEvent(
            id: entry.id, kind: entry.kind, childID: entry.childID, date: entry.date, note: "άλλο", photoIDs: ["a"]
        )

        try await store.profiles.save(FamilyEdit(changed: [ChildEdit(child: renamed, fields: [.name])]))
        try await store.profiles.save(HeroEdit(beard: .full))
        try await store.progress.update(edited)
        _ = try await store.outfit.setChoice(.item("g-mug"), for: .care)
        try await store.standing.keep(titleID: "t1", catalog: .threeTitles)

        let saga = try #require(try await store.wholeSaga.readAll())
        #expect(saga.profile.children.map(\.name) == ["Ελένη", "Νίκος"])
        #expect(saga.profile.dadAppearance.beard == .full)
        #expect(saga.events == [edited])
        #expect(saga.outfit == Outfit(choices: [.care: .item("g-mug")]))
        #expect(saga.kept.titleID == "t1")
        #expect(try await store.progress.referencedPhotoIDs() == ["a"])

        // And the other way: what the whole-saga repository replaces, each of the others reads.
        var restored = saga
        restored.profile.children[1].name = "Νικόλας"
        restored.kept = KeptStanding(titleID: "t2")
        restored.outfit = Outfit(choices: [.play: .hidden])
        restored.events = []
        try await store.wholeSaga.replaceAll(with: restored)

        #expect(try await store.profiles.fetchProfile()?.children.map(\.name) == ["Ελένη", "Νικόλας"])
        #expect(try await store.standing.fetchKept().titleID == "t2")
        #expect(try await store.outfit.fetchOutfit() == Outfit(choices: [.play: .hidden]))
        #expect(try await store.progress.fetchEvents().isEmpty)
    }

    @Test("Given five writes through four repositories at once, when all return, then each landed in a save of its own")
    func concurrentWritesRunOneAtATime() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let (store, _) = try await onboarded()
        let iris = Child(name: "Ίρις", birthDay: nil)
        let second = ProgressEvent(kind: .quest(id: "q2"), childID: nikos.id, date: .now)
        let before = try storeHistory(at: storeURL).count

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { _ = try await store.outfit.setChoice(.hidden, for: .care) }
            group.addTask { try await store.standing.keep(titleID: "t1", catalog: .threeTitles) }
            group.addTask { try await store.profiles.save(FamilyEdit(added: [iris])) }
            group.addTask { try await store.progress.add(second) }
            group.addTask { try await store.profiles.save(HeroEdit(beard: .full)) }
            try await group.waitForAll()
        }

        let saga = try #require(try await store.wholeSaga.readAll())
        #expect(saga.outfit == Outfit(choices: [.care: .hidden]))
        #expect(saga.kept.titleID == "t1")
        #expect(saga.profile.children.map(\.id) == [lena.id, nikos.id, iris.id])
        #expect(saga.events.map(\.id).contains(second.id))
        #expect(saga.profile.dadAppearance.beard == .full)
        // No save carried another turn's change: five transactions of one row each.
        let written = try storeHistory(at: storeURL).dropFirst(before)
        #expect(written.count == 5)
        #expect(written.allSatisfy { $0.count == 1 })
        #expect(Set(written.flatMap(\.self)) == [
            .insert(OutfitRecord.self), .update(ProfileRecord.self, [\ProfileRecord.heldTitleID]),
            .insert(ChildRecord.self), .insert(ProgressEventRecord.self), .update(ProfileRecord.self, [\ProfileRecord.beard])
        ])
    }
}
