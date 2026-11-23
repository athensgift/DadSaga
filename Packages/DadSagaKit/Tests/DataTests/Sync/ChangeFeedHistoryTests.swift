import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// The change feed's two edges and its token (ADR-0065 §2): what was read is kept with its token in one save, the
/// history is deleted behind it, a token whose history is gone is said to be expired, and a batch reads each row's
/// values when it is built. On a store on disk.
@Suite("The change feed's token, and the rows a batch reads", .serialized)
struct ChangeFeedHistoryTests: FeedSuite {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-feed-history-" + UUID().uuidString)
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    @Test("Given changes drained, when drained again, then nothing: the token and what waits were one save")
    func aSecondDrainReadsNothing() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        try await bench.store.profiles.save(HeroEdit(beard: .full))

        let first = try await bench.drain()
        let token = try await bench.ledger.settings().historyToken
        let second = try await bench.drain()

        #expect(first == [.save(.hero(.testDad), fields: ["beard"])])
        #expect(second.isEmpty)
        #expect(token != nil)
        #expect(try await bench.ledger.settings().historyToken == token)
        #expect(try await bench.feed.latestToken() == token)
        // Only the token's own transaction is left of the history.
        #expect(try storeHistory(at: bench.storeURL).count == 1)
    }

    @Test("Given a ledger whose save fails, when the drain stops there, then the next drain reads the same changes")
    func aFailedLedgerSaveLeavesTheHistory() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        let unwritable = try bench.unwritableLedger()
        let waitingBefore = try await bench.ledger.pending()
        try await bench.store.profiles.save(HeroEdit(beard: .full))
        let token = try await unwritable.settings().historyToken
        guard case .changes(let changes, let through) = try await bench.feed.read(after: token) else {
            Issue.record("The token expired")
            return
        }

        await #expect(throws: (any Error).self) { try await unwritable.record(changes, through: through) }

        #expect(try await unwritable.settings().historyToken == token)
        #expect(try await unwritable.pending() == waitingBefore)
        #expect(try await bench.drain() == [.save(.hero(.testDad), fields: ["beard"])])
    }

    @Test("Given history deleted past a token, when read after it, then the feed says the token expired")
    func anExpiredTokenIsSaid() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        let stale = try #require(try await bench.ledger.settings().historyToken)
        try await bench.store.profiles.save(HeroEdit(beard: .full))
        try await bench.drain()
        try await bench.store.profiles.save(HeroEdit(beard: .short))

        #expect(try await bench.feed.read(after: stale) == .tokenExpired)
        // The ledger's own token still reads.
        #expect(try await bench.drain() == [.save(.hero(.testDad), fields: ["beard"])])
    }

    @Test("Given a token of another store, when read after it, then expired: never 'nothing changed'")
    func anotherStoresTokenIsExpired() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        let other = try await FeedBench(in: directory.appending(path: "other"))
        try await other.store.profiles.create(PlayerProfile(children: [nikos], heroClassID: "h-cool"))
        let foreign = try #require(try await other.feed.latestToken())
        try await bench.store.profiles.save(HeroEdit(beard: .full))

        #expect(try await bench.feed.read(after: foreign) == .tokenExpired)
    }

    @Test("Given iCloud off, when the history is trimmed, then it is empty, and a token taken later reads only what follows")
    func trimEmptiesTheHistory() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        let stale = try #require(try await bench.feed.latestToken())
        try await bench.store.profiles.save(HeroEdit(beard: .full))

        try await bench.feed.trim()

        #expect(try storeHistory(at: bench.storeURL).isEmpty)
        #expect(try await bench.feed.latestToken() == nil)
        #expect(try await bench.feed.read(after: nil) == .changes([], through: nil))
        #expect(try await bench.feed.read(after: stale) == .tokenExpired)

        _ = try await bench.store.outfit.setChoice(.hidden, for: .care)
        let token = try #require(try await bench.feed.latestToken())
        try await bench.store.profiles.save(HeroEdit(beard: .short))
        let last = try #require(try await bench.feed.latestToken())

        #expect(token < last)
        #expect(try await bench.feed.read(after: token) == .changes(
            [.save(.hero(.testDad), fields: ["beard"])], through: last
        ))
        #expect(try await bench.feed.read(after: nil) == .changes(
            [.save(.wardrobe(skill: "care"), fields: nil), .save(.hero(.testDad), fields: ["beard"])], through: last
        ))
    }

    @Test("Given changes waiting, when a batch asks for records, then the rows' values now, only the fields asked")
    func recordsReadTheRowsNow() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        let recorded = entry(with: lena, photoIDs: ["a"])
        try await bench.store.progress.add(recorded)
        _ = try await bench.store.outfit.setChoice(.item("g-mug"), for: .care)
        var renamed = lena
        renamed.name = "Ελένη"
        try await bench.store.profiles.save(FamilyEdit(changed: [ChildEdit(child: renamed, fields: [.name])]))
        let family = SyncZone.family(UUID(), owner: "_owner")

        let records = try await bench.feed.records(
            [
                (.child(lena.id), ["name", "birthDay"]), (.entry(recorded.id), ["note", "photoIDs"]),
                (.hero(.testDad), ["beard"]), (.wardrobe(skill: "care"), nil),
                // Gone since, never there, and not a saga row: no record.
                (.child(UUID()), nil), (.entry(UUID()), nil), (.wardrobe(skill: "play"), nil), (.saga, nil),
                (.offer(occasionID: "x/birthday/1"), nil)
            ],
            zones: SyncZones(family: family), gone: []
        )

        #expect(records == [
            SyncRecord(
                name: .child(lena.id), zone: family, fields: ["name": .string("Ελένη"), "birthDay": .string("2025-06-02")]
            ),
            SyncRecord(
                name: .entry(recorded.id), zone: family, fields: ["note": .string("πρώτο"), "photoIDs": .strings(["a"])]
            ),
            SyncRecord(name: .hero(.testDad), zone: .personal, fields: ["beard": .string("none")]),
            SyncRecord(name: .wardrobe(skill: "care"), zone: .personal, fields: ["choice": .string("item:g-mug")])
        ])
    }

    @Test("Given a saga, when sync asks for every record name and each entry's photos, then every row is named once")
    func everyRowIsNamed() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        let (first, second) = (entry(with: lena, photoIDs: ["a", "b"]), entry(with: nikos))
        try await bench.store.progress.add(first)
        try await bench.store.progress.add(second)
        _ = try await bench.store.outfit.setChoice(.hidden, for: .play)
        try await bench.store.profiles.save(FamilyEdit(removedIDs: [nikos.id]))

        let names = try await bench.feed.everyRecordName()

        #expect(names.count == 6)
        #expect(Set(names) == [
            .hero(.testDad), .wardrobe(skill: "play"), .child(lena.id), .child(nikos.id), .entry(first.id), .entry(second.id)
        ])
        #expect(try await bench.feed.entryPhotos() == [first.id: ["a", "b"], second.id: []])
    }

    @Test("Given the feed's stream of saves, when this store saves, then it wakes; another store's save doesn't wake it")
    func aSaveWakesTheFeed() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let bench = try await onboarded()
        let other = try await FeedBench(in: directory.appending(path: "other"))
        let own = bench.feed.saves()
        let others = bench.feed.saves()

        try await other.store.profiles.create(PlayerProfile(children: [nikos], heroClassID: "h-cool"))
        #expect(await yields(others, within: 0.2) == false)

        try await bench.store.profiles.save(HeroEdit(beard: .full))
        #expect(await yields(own, within: 5))
    }
}
