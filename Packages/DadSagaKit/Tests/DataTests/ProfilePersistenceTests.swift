import Application
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

@Suite("Title content")
struct TitleContentTests {
    @Test("Given the bundled JSON, when fetching, then the owner's ten titles load in both languages, each item once")
    func loadsTitles() async throws {
        let catalog = try await BundledContentRepository().fetchCatalog()
        #expect(catalog.titles.map(\.minCards) == [0, 1, 2, 4, 7, 11, 16, 22, 29, 37])
        #expect(catalog.titles.map(\.minXP) == [0, 20, 60, 140, 260, 420, 620, 860, 1140, 1460])
        #expect(catalog.titles[4].name == LocalizedText(el: "Σίγουρα χέρια", en: "Steady hands"))
        #expect(catalog.title(bringing: "g-mug")?.id == "t-new-to-the-journey")
        #expect(catalog.title(bringing: "g-burp-cloth-gold")?.id == "t-super-dad")
        #expect(catalog.titles.flatMap(\.gearIDs).sorted() == catalog.gear.map(\.id).sorted())
    }
}

@Suite("Gear content")
struct GearContentTests {
    @Test("Given the bundled JSON, when fetching, then every slot has two items, the first from an earlier title")
    func loadsGear() async throws {
        let catalog = try await BundledContentRepository().fetchCatalog()
        for skill in Skill.allCases {
            let titles = catalog.gear.filter { $0.skill == skill }.compactMap { catalog.title(bringing: $0.id)?.order }
            #expect(titles.count == 2, "\(skill)")
            #expect(titles.min() ?? 0 > 0)
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
    let birthDay = CalendarDay.day(2025, 3, 15)

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
                Child(name: "Νίκος", birthDay: birthDay, gender: .boy, skinTone: .medium),
                Child(name: "Άννα", birthDay: birthDay.adding(days: -1), gender: .girl, skinTone: .dark)
            ],
            heroClassID: "h-cool",
            dadSkinTone: .mediumDark,
            dadAppearance: DadAppearance(hair: .long, hairColor: .red, beard: .short, glasses: .round)
        )

        try await sut.create(profile)

        #expect(try await sut.fetchProfile() == profile)
    }

    @Test("Given an existing profile, when onboarding creates another, then it throws profileExists and the first stays")
    func createOverAStoredProfile() async throws {
        let sut = LocalStore.inMemory().profiles
        let first = PlayerProfile(
            children: [Child(name: "Νίκος", birthDay: birthDay), Child(name: "Μαρία", birthDay: birthDay)],
            heroClassID: "h-cool"
        )
        try await sut.create(first)

        await #expect(throws: ProfileEditError.profileExists) {
            try await sut.create(PlayerProfile(
                id: UUID(), children: [Child(name: "Άννα", birthDay: birthDay)], heroClassID: "h-smart"
            ))
        }

        #expect(try await sut.fetchProfile() == first)
    }

    @Test("Given no profile, when a family or hero edit saves, then it throws noProfile and nothing is stored")
    func editBeforeOnboarding() async throws {
        let sut = LocalStore.inMemory().profiles

        await #expect(throws: ProfileEditError.noProfile) {
            try await sut.save(FamilyEdit(added: [Child(name: "Άννα", birthDay: nil)]))
        }
        await #expect(throws: ProfileEditError.noProfile) { try await sut.save(HeroEdit(beard: .full)) }

        #expect(try await sut.fetchProfile() == nil)
    }

    @Test("Given an editor opened before another edit added and renamed a child, when it saves, then all of it stays")
    func staleEditKeepsTheOtherChanges() async throws {
        let sut = LocalStore.inMemory().profiles
        let anna = Child(name: "Άννα", birthDay: birthDay)
        try await sut.create(PlayerProfile(children: [anna], heroClassID: "h-cool"))
        // Opened now: shows [Άννα].
        let shown = [anna]
        var renamed = anna
        renamed.name = "Αννούλα"
        let giorgos = Child(name: "Γιώργος", birthDay: nil)
        try await sut.save(FamilyEdit(added: [giorgos], changed: [ChildEdit(child: renamed, fields: [.name])]))

        let vasilis = Child(name: "Βασίλης", birthDay: nil)
        try await sut.save(FamilyEdit(shown: shown, hasPartner: true, edited: [anna, vasilis], hasPartner: true))

        #expect(try await sut.fetchProfile()?.children.map(\.name) == ["Αννούλα", "Γιώργος", "Βασίλης"])
    }

    @Test("Given a profile, events and wardrobe choices, when erasing the saga, then all of them read back empty")
    func eraseAll() async throws {
        let store = LocalStore.inMemory()
        try await store.profiles.create(
            PlayerProfile(children: [Child(name: "Νίκος", birthDay: birthDay)], heroClassID: "h-cool")
        )
        try await store.progress.add(ProgressEvent(kind: .first(id: "f1"), childID: UUID(), date: birth))
        _ = try await store.outfit.setChoice(.hidden, for: .care)

        try await store.wholeSaga.eraseAll()

        #expect(try await store.profiles.fetchProfile() == nil)
        #expect(try await store.progress.fetchEvents().isEmpty)
        #expect(try await store.outfit.fetchOutfit() == Outfit())
    }

    @Test("Given a dad who chose a look, when starting over and onboarding again, then the new dad has the standard look")
    func eraseForgetsLook() async throws {
        let store = LocalStore.inMemory()
        try await store.profiles.create(PlayerProfile(
            children: [Child(name: "Νίκος", birthDay: birthDay)], heroClassID: "h-cool",
            dadAppearance: DadAppearance(hair: .shaved, beard: .none)
        ))

        try await store.wholeSaga.eraseAll()
        try await store.profiles.create(PlayerProfile(children: [Child(name: "Άννα", birthDay: birthDay)], heroClassID: "h-cool"))

        #expect(try await store.profiles.fetchProfile()?.dadAppearance == .standard(for: .mediumLight))
    }

    @Test("Given a stored look part this version doesn't know, when reading, then that part is the standard one")
    func unknownStoredPart() {
        let record = ProfileRecord(
            profileID: .testDad,
            heroClassID: "h-cool", dadSkinTone: "dark", hairStyle: "mohawk", hairColor: "grey", beard: "braided",
            glasses: "round", hasPartner: true
        )

        let look = record.toDomain(children: []).dadAppearance

        #expect(look == DadAppearance(hair: .short, hairColor: .grey, beard: .full, glasses: .round))
    }

    @Test("Given stored events, when fetching, then they come back oldest first with their ids and kinds")
    func progressRoundTrip() async throws {
        let sut = LocalStore.inMemory().progress
        let later = ProgressEvent(
            authorID: UUID(), kind: .first(id: "f1"), childID: UUID(), date: birth.addingTimeInterval(60), note: "Γέλασε"
        )
        let earlier = ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: birth)

        try await sut.add(later)
        try await sut.add(earlier)

        #expect(try await sut.fetchEvents() == [earlier, later])
    }

    @Test("Given a stored entry, when it is updated with another author, then the stored author stays")
    func updateKeepsTheAuthor() async throws {
        let sut = LocalStore.inMemory().progress
        let entry = ProgressEvent(kind: .first(id: "f1"), childID: UUID(), date: birth)
        try await sut.add(entry)

        try await sut.update(ProgressEvent(
            id: entry.id, authorID: UUID(), kind: entry.kind, childID: entry.childID, date: birth, note: "μετά"
        ))

        let stored = try #require(try await sut.fetchEvents().first)
        #expect(stored.authorID == .testDad)
        #expect(stored.note == "μετά")
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

    @Test("Given a stored choice, when it changes and then goes automatic, then the store holds one row, then none")
    func outfitKeepsOneRowPerSlot() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-outfit-rows-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sut = LocalStore.live(in: directory).outfit
        let url = directory.appending(path: "DadSaga.store")

        _ = try await sut.setChoice(.hidden, for: .care)
        let changed = try await sut.setChoice(.item("g-burp-cloth"), for: .care)
        #expect(changed == Outfit(choices: [.care: .item("g-burp-cloth")]))
        #expect(try storedRowCount(OutfitRecord.self, at: url) == 1)

        #expect(try await sut.setChoice(.automatic, for: .care) == Outfit())
        #expect(try storedRowCount(OutfitRecord.self, at: url) == 0)
        #expect(try await LocalStore.live(in: directory).outfit.fetchOutfit() == Outfit())
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

    @Test("Given a boss and a first the partner recorded, when the dad adds both, then his boss is added, his first isn't")
    func addUnlessRecordedChecksTheAuthorForABossOnly() async throws {
        let sut = LocalStore.inMemory().progress
        let child = UUID()
        let partner = UUID()
        try await sut.add(ProgressEvent(authorID: partner, kind: .boss(id: "b"), childID: child, date: birth))
        try await sut.add(ProgressEvent(authorID: partner, kind: .first(id: "f"), childID: child, date: birth))

        #expect(try await sut.addUnlessRecorded(ProgressEvent(kind: .boss(id: "b"), childID: child, date: birth)))
        #expect(try await !sut.addUnlessRecorded(ProgressEvent(kind: .boss(id: "b"), childID: child, date: birth)))
        #expect(try await !sut.addUnlessRecorded(ProgressEvent(kind: .first(id: "f"), childID: child, date: birth)))
        #expect(try await sut.fetchEvents().map(\.authorID).sorted() == [partner, partner, .testDad].sorted())
    }

    @Test("Given the most photos an entry keeps, when saved and read back from disk, then they come back in the same order")
    func photosKeepTheirOrder() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-photos-order-" + UUID().uuidString)
        let ids = (1...ProgressEvent.photoLimit).map { "photo-\(ProgressEvent.photoLimit + 1 - $0)" }
        let event = ProgressEvent(kind: .first(id: "f1"), childID: UUID(), date: birth, photoIDs: ids)

        try await LocalStore.live(in: directory).progress.add(event)

        #expect(try await LocalStore.live(in: directory).progress.fetchEvents().first?.photoIDs == ids)
    }

    @Test("Given an event deleted meanwhile, when updating it, then it throws unknownEvent and nothing is added")
    func updatingAMissingEventThrows() async throws {
        let sut = LocalStore.inMemory().progress

        await #expect(throws: ProgressError.unknownEvent) {
            try await sut.update(ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: birth))
        }
        #expect(try await sut.fetchEvents().isEmpty)
    }

    @Test("Given a record of a kind this version does not know, when mapping, then it is skipped")
    func unknownKindIsSkipped() {
        let record = ProgressEventRecord(event: ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: birth))
        record.kind = "future-kind"
        #expect(record.toDomain() == nil)
    }
}
