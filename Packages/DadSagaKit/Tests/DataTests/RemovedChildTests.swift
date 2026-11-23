import Application
import Domain
import Foundation
import Testing
@testable import Data

/// A child removed from the family (ADR-0065 §4, §8): set by removing in "My family", cleared by bringing them back,
/// carried by a copy, and gone only when deleted for good. Listed only on "My family" and in none of the family's
/// counts, their entries still counting for their author; removing and bringing back change no one's standing.
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
        #expect(try await phone.store.wholeSaga.readAll()?.profile.removedChildren == [removed])
        #expect(try await home(on: phone, childID: removed.id)?.child.id == lena.id)
        let timeline = try await DefaultGetTimelineUseCase(
            contentRepository: BundledContentRepository(), wholeSaga: phone.store.wholeSaga
        ).execute()
        #expect(!timeline.isEmpty)
        #expect(timeline.allSatisfy { $0.childID != removed.id })
    }

    @Test("Given an imported removed child, when reading home, then the dad's entries with them count, the partner's don't")
    func theirEntriesStillCount() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let phone = try await imported().phone
        let catalog = try await BundledContentRepository().fetchCatalog()
        let fever = dads(.boss(id: "b-w1-first-fever"), childID: removed.id, date: madeAt.addingTimeInterval(-3_000))
        let before = try #require(try await home(on: phone, childID: nil)?.progress)

        try await phone.store.progress.add(fever)
        let after = try #require(try await home(on: phone, childID: nil)?.progress)

        #expect(after.totalXP > before.totalXP)
        #expect(after.defeatedBossIDs(for: removed.id) == ["b-w1-first-fever"])
        // Every card in the timeline but the partner's first with the removed child.
        let listed = Timeline.entries(from: try await phone.store.progress.fetchEvents(), catalog: catalog)
        #expect(listed.contains { $0.authorID == SagaCopyPeople.partnerID })
        #expect(after.cardsDone == listed.count - 1)
    }

    @Test("Given four children and a removed one, when the family is renamed and saved, then the removed row stays")
    func familySaveLeavesThemAlone() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let phone = try await imported().phone
        var family = [lena, unborn, Child(name: "Γιάννης", birthDay: nil), Child(name: "Μαρία", birthDay: nil)]
        try await DefaultUpdateFamilyUseCase(profileRepository: phone.store.profiles)
            .execute(FamilyEdit(added: Array(family.suffix(2))), on: madeAt)
        family[0].name = "Λενιώ"

        try await DefaultUpdateFamilyUseCase(profileRepository: phone.store.profiles)
            .execute(FamilyEdit(changed: [ChildEdit(child: family[0], fields: [.name])]), on: madeAt)

        let saga = try #require(try await phone.store.wholeSaga.readAll())
        #expect(saga.profile.children.map(\.name) == family.map(\.name))
        #expect(saga.profile.removedChildren == [removed])
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
        #expect(again.profile.removedChildren == [removed])
        #expect(again.profile.children == original.profile.children)
        #expect(again.events.map(\.authorID) == original.events.map(\.authorID))
    }

    // MARK: - Removing, bringing back, deleting for good

    struct Standing: Equatable {
        let totalXP: Int
        let cardsDone: Int
        let titleID: String?
        let skillXP: [Skill: Int]
    }

    func standing(on phone: Phone) async throws -> Standing {
        let home = try #require(try await home(on: phone, childID: nil))
        return Standing(
            totalXP: home.progress.totalXP, cardsDone: home.progress.cardsDone, titleID: home.standing.title?.id,
            skillXP: Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, home.progress.skillXP[$0] ?? 0) })
        )
    }

    func remove(_ child: Child, on phone: Phone) async throws {
        try await DefaultUpdateFamilyUseCase(profileRepository: phone.store.profiles)
            .execute(FamilyEdit(removedIDs: [child.id]), on: madeAt)
    }

    func deleteForGood(on phone: Phone) -> DefaultDeleteChildForGoodUseCase {
        DefaultDeleteChildForGoodUseCase(
            contentRepository: BundledContentRepository(), profileRepository: phone.store.profiles,
            progressRepository: phone.store.progress, standingRepository: phone.store.standing, photoStore: phone.photos
        )
    }

    /// The dad, Λένα and the one not born yet; the dad's two quests with Λένα bring "t-apprentice-dad" (2 cards, 65 XP),
    /// one with a photo; one quest of his with the other child.
    func family() async throws -> (phone: Phone, photo: String) {
        let phone = phone("family")
        try await phone.store.profiles.create(PlayerProfile(
            id: SagaCopyPeople.dadID, children: [lena, unborn], heroClassID: "h-chef"
        ))
        let photo = try await phone.photos.save(try png(width: 40, height: 20))
        for event in [
            dads(.quest(id: "q-w0-appointment"), childID: lena.id, date: madeAt.addingTimeInterval(-3_000), photoIDs: [photo]),
            dads(.quest(id: "q-w0-birth-partner"), childID: lena.id, date: madeAt.addingTimeInterval(-2_000))
        ] {
            try await phone.store.progress.add(event)
        }
        return (phone, photo)
    }

    @Test("Given a child with entries, when removed and brought back, then no standing changes and they return in place")
    func removingAndBringingBackChangeNoStanding() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let (phone, _) = try await family()
        let before = try await standing(on: phone)

        try await remove(lena, on: phone)
        let removedStanding = try await standing(on: phone)
        let profile = try #require(try await phone.store.profiles.fetchProfile())
        let timeline = try await DefaultGetTimelineUseCase(
            contentRepository: BundledContentRepository(), wholeSaga: phone.store.wholeSaga
        ).execute()
        let homeChild = try await home(on: phone, childID: lena.id)?.child.id
        try await DefaultBringBackChildUseCase(profileRepository: phone.store.profiles).execute(childID: lena.id)
        let back = try #require(try await phone.store.profiles.fetchProfile())

        #expect(before.titleID == "t-apprentice-dad")
        #expect(removedStanding == before)
        #expect(profile.children.map(\.id) == [unborn.id])
        #expect(profile.removedChildren.map(\.id) == [lena.id])
        #expect(homeChild == unborn.id)
        #expect(timeline.isEmpty)
        #expect(try await standing(on: phone) == before)
        #expect(back.children.map(\.id) == [lena.id, unborn.id])
        #expect(back.removedChildren.isEmpty)
        let timelineBack = try await DefaultGetTimelineUseCase(
            contentRepository: BundledContentRepository(), wholeSaga: phone.store.wholeSaga
        ).execute()
        #expect(timelineBack.count == 2)
    }

    @Test("Given four in the family and a removed child, when bringing them back, then it is refused and nothing is written")
    func bringingBackIsRefusedAtFour() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let (phone, _) = try await family()
        try await remove(lena, on: phone)
        let others = ["Γιάννης", "Μαρία", "Άρης"].map { Child(name: $0, birthDay: nil) }
        try await DefaultUpdateFamilyUseCase(profileRepository: phone.store.profiles)
            .execute(FamilyEdit(added: others), on: madeAt)

        await #expect(throws: ProfileValidationError.tooManyChildren) {
            try await DefaultBringBackChildUseCase(profileRepository: phone.store.profiles).execute(childID: lena.id)
        }
        let profile = try #require(try await phone.store.profiles.fetchProfile())
        #expect(profile.children.count == 4)
        #expect(profile.removedChildren.map(\.id) == [lena.id])
    }

    @Test("Given the title came from a removed child's entries, when deleted for good, then their XP goes and the title stays")
    func deletingForGoodTakesTheXPAndKeepsTheTitle() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let (phone, photo) = try await family()
        let partners = ProgressEvent(
            authorID: SagaCopyPeople.partnerID, kind: .first(id: "f-smile"), childID: lena.id, date: madeAt
        )
        try await phone.store.progress.add(partners)
        let keptPhoto = try await phone.photos.save(try png(width: 60, height: 30))
        let other = dads(
            .quest(id: "q-w0-go-bag"), childID: unborn.id, date: madeAt.addingTimeInterval(-1_000), photoIDs: [keptPhoto]
        )
        try await phone.store.progress.add(other)
        try await remove(lena, on: phone)

        try await deleteForGood(on: phone).execute(childID: lena.id)

        let after = try await standing(on: phone)
        #expect(after.totalXP == 20)
        #expect(after.titleID == "t-apprentice-dad")
        #expect(try await phone.store.progress.fetchEvents().map(\.id) == [other.id])
        #expect(try await phone.store.profiles.fetchProfile()?.removedChildren.isEmpty == true)
        #expect(try await phone.store.profiles.fetchProfile()?.children.map(\.id) == [unborn.id])
        #expect((try? await phone.photos.storedData(id: photo)) == nil)
        #expect((try? await phone.photos.storedData(id: keptPhoto)) != nil)
    }

    @Test("Given a child in the family or an unknown id, when deleting for good, then notRemoved and nothing is written")
    func deletingForGoodOnlyARemovedChild() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let (phone, photo) = try await family()
        let before = try #require(try await phone.store.wholeSaga.readAll())

        await #expect(throws: ProfileEditError.notRemoved) { try await deleteForGood(on: phone).execute(childID: lena.id) }
        await #expect(throws: ProfileEditError.notRemoved) {
            try await phone.store.profiles.deleteForGood(childID: lena.id)
        }
        await #expect(throws: ProfileEditError.notRemoved) { try await deleteForGood(on: phone).execute(childID: UUID()) }

        #expect(try await phone.store.wholeSaga.readAll() == before)
        #expect((try? await phone.photos.storedData(id: photo)) != nil)
    }

    @Test("Given a removed child, when a copy is made, then it carries them removed; after deleting for good, not at all")
    func copiesFollowTheMark() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try await family().phone
        try await remove(lena, on: source)

        let removedCopy = try await make(on: source).execute(on: madeAt) { _ in }
        let first = phone("first")
        try await restore(on: first).restore(try await restore(on: first).open(fileAt: removedCopy.url) { _ in }, on: madeAt)
        try await deleteForGood(on: source).execute(childID: lena.id)
        let deletedCopy = try await make(on: source).execute(on: madeAt) { _ in }
        let second = phone("second")
        try await restore(on: second).restore(try await restore(on: second).open(fileAt: deletedCopy.url) { _ in }, on: madeAt)

        #expect(try await first.store.profiles.fetchProfile()?.removedChildren.map(\.id) == [lena.id])
        let afterDeletion = try #require(try await second.store.wholeSaga.readAll())
        #expect(afterDeletion.profile.removedChildren.isEmpty)
        #expect(afterDeletion.profile.children.map(\.id) == [unborn.id])
        #expect(afterDeletion.events.isEmpty)
    }
}
