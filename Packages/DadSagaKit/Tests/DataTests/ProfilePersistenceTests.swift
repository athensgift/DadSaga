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

    @Test("Given a profile, events and wardrobe choices, when erasing the saga, then all of them read back empty")
    func eraseAll() async throws {
        let store = LocalStore.inMemory()
        try await store.profiles.save(
            PlayerProfile(children: [Child(name: "Νίκος", birthDate: birth)], heroClassID: "h-cool")
        )
        try await store.progress.add(ProgressEvent(kind: .first(id: "f1"), childID: UUID(), date: birth))
        _ = try await store.outfit.setChoice(.hidden, for: .care)

        try await store.eraser.eraseAll()

        #expect(try await store.profiles.fetchProfile() == nil)
        #expect(try await store.progress.fetchEvents().isEmpty)
        #expect(try await store.outfit.fetchOutfit() == Outfit())
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
        let moment = ProgressEvent(kind: .first(id: "f1"), childID: UUID(), date: birth, note: "πριν", photoIDs: ["p1"])
        try await sut.add(quest)
        try await sut.add(moment)

        let changed = ProgressEvent(
            id: moment.id, kind: moment.kind, childID: moment.childID,
            date: birth.addingTimeInterval(60), note: "μετά", photoIDs: ["p2", "p1"]
        )
        try await sut.update(changed)
        #expect(try await sut.fetchEvents() == [quest, changed])

        try await sut.delete(id: moment.id)
        #expect(try await sut.fetchEvents() == [quest])
    }

    @Test("Given wardrobe choices, when setting slots one by one, then each keeps the others")
    func outfitRoundTrip() async throws {
        let sut = LocalStore.inMemory().outfit

        _ = try await sut.setChoice(.item("g-burp-cloth"), for: .care)
        let outfit = try await sut.setChoice(.hidden, for: .play)
        #expect(outfit == Outfit(choices: [.care: .item("g-burp-cloth"), .play: .hidden]))
        #expect(try await sut.fetchOutfit() == outfit)

        #expect(try await sut.setChoice(.automatic, for: .care) == Outfit(choices: [.play: .hidden]))
    }

    @Test("Given two slots changed at the same moment, when both run, then both choices are kept")
    func outfitSlotsDoNotOverwrite() async throws {
        let sut = LocalStore.inMemory().outfit

        async let care = sut.setChoice(.hidden, for: .care)
        async let play = sut.setChoice(.item("g-duck"), for: .play)
        _ = try await (care, play)

        #expect(try await sut.fetchOutfit() == Outfit(choices: [.care: .hidden, .play: .item("g-duck")]))
    }

    @Test("Given stored choice text, when decoding, then known values map and unknown ones are ignored")
    func outfitCoding() {
        #expect(OutfitCoding.decode("hidden") == .hidden)
        #expect(OutfitCoding.decode("item:g-mug") == .item("g-mug"))
        #expect(OutfitCoding.decode("sparkly") == nil)
        #expect(OutfitCoding.encode(.automatic) == nil)
        #expect(OutfitCoding.encode(.item("g-mug")) == "item:g-mug")
    }

    @Test("Given two saves of the same boss for one child at the same moment, when both run, then exactly one is stored")
    func addUnlessRecordedIsAtomic() async throws {
        let sut = LocalStore.inMemory().progress
        let child = UUID()
        let first = ProgressEvent(kind: .boss(id: "b1"), childID: child, date: birth)
        let second = ProgressEvent(kind: .boss(id: "b1"), childID: child, date: birth)

        async let addedFirst = sut.addUnlessRecorded(first)
        async let addedSecond = sut.addUnlessRecorded(second)
        let added = try await [addedFirst, addedSecond]

        #expect(added.filter { $0 }.count == 1)
        #expect(try await sut.fetchEvents().count == 1)
    }

    @Test("Given a boss stored for one child, when adding it for another child or as another kind, then both are stored")
    func addUnlessRecordedIsPerChildAndKind() async throws {
        let sut = LocalStore.inMemory().progress
        let child = UUID()
        try await sut.add(ProgressEvent(kind: .boss(id: "x"), childID: child, date: birth))

        #expect(try await sut.addUnlessRecorded(ProgressEvent(kind: .boss(id: "x"), childID: UUID(), date: birth)))
        #expect(try await sut.addUnlessRecorded(ProgressEvent(kind: .first(id: "x"), childID: child, date: birth)))
        #expect(try await !sut.addUnlessRecorded(ProgressEvent(kind: .boss(id: "x"), childID: child, date: birth)))
        #expect(try await sut.fetchEvents().count == 3)
    }

    @Test("Given a record of a kind this version does not know, when mapping, then it is skipped")
    func unknownKindIsSkipped() {
        let record = ProgressEventRecord(event: ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: birth))
        record.kind = "future-kind"
        #expect(record.toDomain() == nil)
    }
}
