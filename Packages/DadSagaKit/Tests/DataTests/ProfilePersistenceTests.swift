import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

@Suite("Hero classes content")
struct HeroClassContentTests {
    @Test("Given the bundled JSON, when fetching, then the six hero classes load in order with text in both languages")
    func loadsHeroClasses() async throws {
        let catalog = try await BundledContentRepository().fetchCatalog()
        #expect(catalog.heroClasses.map(\.id) == ["h-super", "h-cool", "h-strong", "h-smart", "h-chef", "h-fixer"])
        for hero in catalog.heroClasses {
            #expect(!hero.title.el.isEmpty && !hero.title.en.isEmpty)
            #expect(!hero.tagline.el.isEmpty && !hero.tagline.en.isEmpty)
        }
    }
}

@Suite("Gear content")
struct GearContentTests {
    @Test("Given the bundled JSON, when fetching, then every skill has two gear tiers with text in both languages")
    func loadsGear() async throws {
        let catalog = try await BundledContentRepository().fetchCatalog()
        for skill in Skill.allCases {
            let tiers = catalog.gear.filter { $0.skill == skill }.map(\.minXP).sorted()
            #expect(tiers.count == 2, "\(skill)")
            #expect(tiers.first ?? 0 > 0)
        }
        for item in catalog.gear {
            #expect(!item.title.el.isEmpty && !item.title.en.isEmpty)
        }
    }
}

/// Serialized: creating several SwiftData containers for the same model at once can crash the test process.
@Suite("LocalStore", .serialized)
struct LocalStoreTests {
    let birth = Date(timeIntervalSince1970: 1_000_000)

    @Test("Given an empty store, when fetching, then there is no profile")
    func emptyStore() async throws {
        let sut = LocalStore.inMemory().profiles
        #expect(try await sut.fetchProfile() == nil)
    }

    @Test("Given a saved profile, when fetching, then the same profile is returned")
    func roundTrip() async throws {
        let sut = LocalStore.inMemory().profiles
        let profile = PlayerProfile(
            children: [
                Child(name: "Νίκος", birthDate: birth, gender: .boy, skinTone: .medium),
                Child(name: "Άννα", birthDate: birth.addingTimeInterval(-86_400), gender: .girl, skinTone: .dark)
            ],
            heroClassID: "h-cool",
            dadSkinTone: .mediumDark
        )

        try await sut.save(profile)

        #expect(try await sut.fetchProfile() == profile)
    }

    @Test("Given an existing profile, when saving again, then it is replaced rather than duplicated")
    func saveReplaces() async throws {
        let sut = LocalStore.inMemory().profiles
        try await sut.save(
            PlayerProfile(
                children: [Child(name: "Νίκος", birthDate: birth), Child(name: "Μαρία", birthDate: birth)],
                heroClassID: "h-cool"
            )
        )
        let updated = PlayerProfile(children: [Child(name: "Άννα", birthDate: birth)], heroClassID: "h-smart")

        try await sut.save(updated)

        #expect(try await sut.fetchProfile() == updated)
    }

    @Test("Given a saved profile, when deleting, then the store is empty again")
    func delete() async throws {
        let sut = LocalStore.inMemory().profiles
        try await sut.save(PlayerProfile(children: [Child(name: "Νίκος", birthDate: birth)], heroClassID: "h-cool"))

        try await sut.deleteProfile()

        #expect(try await sut.fetchProfile() == nil)
    }

    @Test("Given stored events, when fetching, then they come back oldest first with their ids and kinds")
    func progressRoundTrip() async throws {
        let sut = LocalStore.inMemory().progress
        let later = ProgressEvent(kind: .first(id: "f1"), childID: UUID(), date: birth.addingTimeInterval(60), note: "Γέλασε")
        let earlier = ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: birth)

        try await sut.add(later)
        try await sut.add(earlier)

        #expect(try await sut.fetchEvents() == [earlier, later])
    }

    @Test("Given a stored moment, when updating then deleting it, then the changes are stored and other events stay")
    func progressUpdateAndDelete() async throws {
        let sut = LocalStore.inMemory().progress
        let quest = ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: birth)
        let moment = ProgressEvent(kind: .first(id: "f1"), childID: UUID(), date: birth, note: "πριν", photoID: "p1")
        try await sut.add(quest)
        try await sut.add(moment)

        let changed = ProgressEvent(
            id: moment.id, kind: moment.kind, childID: moment.childID,
            date: birth.addingTimeInterval(60), note: "μετά", photoID: nil
        )
        try await sut.update(changed)
        #expect(try await sut.fetchEvents() == [quest, changed])

        try await sut.delete(id: moment.id)
        #expect(try await sut.fetchEvents() == [quest])
    }

    @Test("Given wardrobe choices, when saving and fetching, then they round-trip and deleting clears them")
    func outfitRoundTrip() async throws {
        let sut = LocalStore.inMemory().outfit
        let outfit = Outfit(choices: [.care: .item("g-burp-cloth"), .play: .hidden])

        try await sut.save(outfit)
        #expect(try await sut.fetchOutfit() == outfit)

        try await sut.save(Outfit(choices: [.patience: .hidden]))
        #expect(try await sut.fetchOutfit() == Outfit(choices: [.patience: .hidden]))

        try await sut.deleteAll()
        #expect(try await sut.fetchOutfit() == Outfit())
    }

    @Test("Given stored choice text, when decoding, then known values map and unknown ones are ignored")
    func outfitCoding() {
        #expect(OutfitCoding.decode("hidden") == .hidden)
        #expect(OutfitCoding.decode("item:g-mug") == .item("g-mug"))
        #expect(OutfitCoding.decode("sparkly") == nil)
        #expect(OutfitCoding.encode(.automatic) == nil)
        #expect(OutfitCoding.encode(.item("g-mug")) == "item:g-mug")
    }

    @Test("Given stored events, when deleting all, then the log is empty")
    func progressDeleteAll() async throws {
        let sut = LocalStore.inMemory().progress
        try await sut.add(ProgressEvent(kind: .first(id: "f1"), childID: UUID(), date: birth))

        try await sut.deleteAll()

        #expect(try await sut.fetchEvents().isEmpty)
    }

    @Test("Given a record of a kind this version does not know, when mapping, then it is skipped")
    func unknownKindIsSkipped() {
        let record = ProgressEventRecord(event: ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: birth))
        record.kind = "future-kind"
        #expect(record.toDomain() == nil)
    }
}
