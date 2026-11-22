import Application
import Domain
import Foundation
import Testing
@testable import Data

/// A child removed from the family, as a copy from the co-op version may bring one: stored, read and kept, never set
/// (ADR-0065 §5, §8). On no screen and in none of the family's counts, their entries still counting for their author.
@Suite("A child removed from the family", .serialized)
struct RemovedChildTests: SagaCopyBench {
    let root = FileManager.default.temporaryDirectory.appending(path: "dadsaga-removed-" + UUID().uuidString)
    let madeAt = Date(timeIntervalSinceReferenceDate: 815_000_000)

    struct Imported {
        let phone: Phone
        let original: StoredSaga
        let childNames: [String]
    }

    /// The saga `fill` makes, with its removed child, copied and imported on a new phone.
    func imported() async throws -> Imported {
        let old = phone("old")
        _ = try await fill(old)
        let original = try #require(try await old.store.wholeSaga.readAll())
        let made = try await make(on: old).execute(on: madeAt) { _ in }
        let new = phone("new")
        let opened = try await restore(on: new).open(fileAt: made.url) { _ in }
        try await restore(on: new).restore(opened, on: madeAt)
        return Imported(phone: new, original: original, childNames: opened.childNames)
    }

    func home(on phone: Phone, childID: UUID?) async throws -> HomeOverview? {
        try await DefaultGetHomeOverviewUseCase(
            contentRepository: BundledContentRepository(), profileRepository: phone.store.profiles,
            progressRepository: phone.store.progress, outfitRepository: phone.store.outfit,
            standingRepository: phone.store.standing, sagaOfferRepository: phone.offers, timeZone: .gmt
        ).execute(childID: childID, worldID: nil, on: madeAt)
    }

    @Test("Given a copy with a removed child, when imported, then the restore, the family, home and timeline leave them out")
    func removedChildIsOnNoScreen() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let imported = try await imported()
        let (phone, childNames) = (imported.phone, imported.childNames)

        #expect(childNames == [lena.name, unborn.name])
        #expect(try await phone.store.profiles.fetchProfile()?.children.map(\.id) == [lena.id, unborn.id])
        #expect(try await phone.store.wholeSaga.readAll()?.removedChildren == [removed])
        #expect(try await home(on: phone, childID: removed.id)?.child.id == lena.id)
        let timeline = try await DefaultGetTimelineUseCase(
            contentRepository: BundledContentRepository(), progressRepository: phone.store.progress,
            profileRepository: phone.store.profiles
        ).execute()
        #expect(!timeline.isEmpty)
        #expect(timeline.allSatisfy { $0.childID != removed.id })
    }

    @Test("Given an imported removed child, when reading home, then their entry still counts in the dad's progress")
    func theirEntriesStillCount() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let imported = try await imported()
        let (phone, original) = (imported.phone, imported.original)
        let catalog = try await BundledContentRepository().fetchCatalog()
        let withoutThem = original.events.filter { $0.childID != removed.id }

        let progress = try #require(try await home(on: phone, childID: nil)?.progress)

        #expect(progress == DadProgress(events: try await phone.store.progress.fetchEvents(), catalog: catalog))
        #expect(progress.totalXP > DadProgress(events: withoutThem, catalog: catalog).totalXP)
    }

    @Test("Given four children and a removed one, when the family is renamed and saved, then the removed row stays")
    func familySaveLeavesThemAlone() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let phone = try await imported().phone
        var family = [lena, unborn, Child(name: "Γιάννης", birthDay: nil), Child(name: "Μαρία", birthDay: nil)]
        try await DefaultUpdateFamilyUseCase(profileRepository: phone.store.profiles)
            .execute(children: family, hasPartner: true, on: madeAt)
        family[0].name = "Λενιώ"

        try await DefaultUpdateFamilyUseCase(profileRepository: phone.store.profiles)
            .execute(children: family, hasPartner: true, on: madeAt)

        let saga = try #require(try await phone.store.wholeSaga.readAll())
        #expect(saga.profile.children.map(\.name) == family.map(\.name))
        #expect(saga.removedChildren == [removed])
        #expect(saga.events.contains { $0.childID == removed.id })
    }

    @Test("Given an imported removed child, when a copy is made again and read, then it carries them, still removed")
    func copiedAgain() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let imported = try await imported()
        let (new, original) = (imported.phone, imported.original)

        let made = try await make(on: new).execute(on: madeAt) { _ in }
        let other = phone("other")
        try await restore(on: other).restore(try await restore(on: other).open(fileAt: made.url) { _ in }, on: madeAt)

        let again = try #require(try await other.store.wholeSaga.readAll())
        #expect(again.removedChildren == [removed])
        #expect(again.profile.children == original.profile.children)
        #expect(again.events.map(\.authorID) == original.events.map(\.authorID))
    }
}
