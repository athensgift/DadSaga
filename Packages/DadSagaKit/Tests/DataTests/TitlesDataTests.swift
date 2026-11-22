import Application
import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// What the profile keeps for titles, from a store written before them (ADR-0055 §5).
@Suite("Titles in the store", .serialized)
struct TitlesStoreTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-titles-" + UUID().uuidString)

    @Test("Given a store written by version 6, when the app opens it, then everything is there and nothing is kept yet")
    func version6BecomesVersion7() async throws {
        try StoreFiles.copy(from: StoreV6Fixture.directory, to: directory)
        let store = LocalStore.live(in: directory)

        #expect(try await store.profiles.fetchProfile() == StoreV6Fixture.profile)
        #expect(try await store.progress.fetchEvents() == StoreV6Fixture.events)
        #expect(try await store.outfit.fetchOutfit() == StoreV6Fixture.outfit)
        #expect(try await store.standing.fetchKept() == KeptStanding())
    }

    @Test("Given a new saga, when the profile is saved, then nothing is kept, and edits keep the title")
    func newProfileStartsFresh() async throws {
        let store = LocalStore.inMemory()
        #expect(try await store.standing.fetchKept() == KeptStanding())
        try await store.standing.keep(titleID: "t1")
        #expect(try await store.standing.fetchKept() == KeptStanding())

        try await store.profiles.save(StoreV6Fixture.profile)
        #expect(try await store.standing.fetchKept() == KeptStanding())
        try await store.standing.keep(titleID: "t2")
        try await store.standing.markSeen(titleID: "t2")
        try await store.profiles.save(PlayerProfile(children: [StoreV6Fixture.eleni], heroClassID: "h-super"))

        #expect(try await store.standing.fetchKept() == KeptStanding(titleID: "t2", seenTitleID: "t2"))
    }

    @Test("Given a card closed for a title an Undo takes back, when the title still held is marked seen, then it goes back")
    func markSeenGoesBackForAnUndo() async throws {
        let store = LocalStore.inMemory()
        try await store.profiles.save(StoreV6Fixture.profile)
        try await store.standing.keep(titleID: "t1")
        try await store.standing.markSeen(titleID: "t2")

        try await store.standing.markSeen(titleID: "t1")

        #expect(try await store.standing.fetchKept() == KeptStanding(titleID: "t1", seenTitleID: "t1"))
    }

    @Test("Given no family yet, when a title is marked seen, then nothing is written")
    func markSeenWithoutAFamily() async throws {
        let store = LocalStore.inMemory()

        try await store.standing.markSeen(titleID: "t2")

        #expect(try await store.standing.fetchKept() == KeptStanding())
    }

    @Test("Given a kept title, when the dad starts over, then it goes with the saga")
    func startOverErasesIt() async throws {
        let store = LocalStore.inMemory()
        try await store.profiles.save(StoreV6Fixture.profile)
        try await store.standing.keep(titleID: "t2")

        try await store.wholeSaga.eraseAll()
        try await store.profiles.save(StoreV6Fixture.profile)

        #expect(try await store.standing.fetchKept() == KeptStanding())
    }
}

@Suite("Title content validation")
struct TitleValidationTests {
    let text = LocalizedText(el: "x", en: "x")
    var mug: GearItem { GearItem(id: "mug", skill: .patience, look: "mug", title: text) }

    func catalog(_ titles: [DadTitle], gear: [GearItem]? = nil) -> ContentCatalog {
        ContentCatalog(
            worlds: [], quests: [], bosses: [], firsts: [], gear: gear ?? [mug], titles: titles,
            skillCurves: SkillCurve.forEverySkill,
            appearanceOptions: DadAppearance.Part.allCases.flatMap { part in
                DadAppearance.optionIDs(for: part).map { DadAppearanceOption(part: part, id: $0, title: text) }
            }
        )
    }

    @Test("Given a first title that needs a card, when validating, then invalidTitleThresholds is thrown")
    func firstNeedsNothing() {
        #expect(throws: ContentDataError.invalidTitleThresholds(titleID: "t0")) {
            try ContentValidator.validate(catalog([
                DadTitle(id: "t0", order: 0, minCards: 1, minXP: 0, gearIDs: ["mug"], name: text)
            ]))
        }
    }

    @Test("Given a title that needs no more cards than the one before, when validating, then it is rejected")
    func eachNeedsMore() {
        #expect(throws: ContentDataError.invalidTitleThresholds(titleID: "t2")) {
            try ContentValidator.validate(catalog([
                DadTitle(id: "t0", order: 0, minCards: 0, minXP: 0, name: text),
                DadTitle(id: "t1", order: 1, minCards: 2, minXP: 20, gearIDs: ["mug"], name: text),
                DadTitle(id: "t2", order: 2, minCards: 2, minXP: 60, name: text)
            ]))
        }
    }

    @Test("Given a title that brings an item the content lacks, when validating, then unknownGear is thrown")
    func unknownGear() {
        #expect(throws: ContentDataError.unknownGear(titleID: "t0", gearID: "hat")) {
            try ContentValidator.validate(catalog([
                DadTitle(id: "t0", order: 0, minCards: 0, minXP: 0, gearIDs: ["mug", "hat"], name: text)
            ]))
        }
    }

    @Test("Given an item no title brings, or two titles bring, when validating, then it is rejected")
    func eachItemOnce() {
        let cloth = GearItem(id: "cloth", skill: .care, look: "burpCloth", title: text)
        #expect(throws: ContentDataError.gearWithoutTitle(gearID: "cloth")) {
            try ContentValidator.validate(catalog([
                DadTitle(id: "t0", order: 0, minCards: 0, minXP: 0, gearIDs: ["mug"], name: text)
            ], gear: [mug, cloth]))
        }
        #expect(throws: ContentDataError.gearInTwoTitles(gearID: "mug")) {
            try ContentValidator.validate(catalog([
                DadTitle(id: "t0", order: 0, minCards: 0, minXP: 0, gearIDs: ["mug"], name: text),
                DadTitle(id: "t1", order: 1, minCards: 1, minXP: 20, gearIDs: ["mug"], name: text)
            ]))
        }
    }

    @Test("Given a title with an empty name, when validating, then emptyText is thrown")
    func nameSaysSomething() {
        #expect(throws: ContentDataError.emptyText(itemID: "t0")) {
            try ContentValidator.validate(catalog([
                DadTitle(id: "t0", order: 0, minCards: 0, minXP: 0, gearIDs: ["mug"], name: LocalizedText(el: "", en: "x"))
            ]))
        }
    }

    @Test("Given titles whose orders run 0, 1, 2, when validating, then they pass")
    func ordersWithoutGaps() throws {
        try ContentValidator.validate(catalog([
            DadTitle(id: "t0", order: 0, minCards: 0, minXP: 0, name: text),
            DadTitle(id: "t1", order: 1, minCards: 1, minXP: 20, gearIDs: ["mug"], name: text),
            DadTitle(id: "t2", order: 2, minCards: 2, minXP: 60, name: text)
        ]))
    }

    @Test("Given titles with a gap in their orders, when validating, then invalidTitleOrder is thrown: a level is skipped")
    func orderWithAGap() {
        #expect(throws: ContentDataError.invalidTitleOrder(titleID: "t2")) {
            try ContentValidator.validate(catalog([
                DadTitle(id: "t0", order: 0, minCards: 0, minXP: 0, name: text),
                DadTitle(id: "t1", order: 1, minCards: 1, minXP: 20, gearIDs: ["mug"], name: text),
                DadTitle(id: "t2", order: 3, minCards: 2, minXP: 60, name: text)
            ]))
        }
    }

    @Test("Given two titles with one order, when validating, then invalidTitleOrder is thrown")
    func orderRepeated() {
        #expect(throws: ContentDataError.invalidTitleOrder(titleID: "t2")) {
            try ContentValidator.validate(catalog([
                DadTitle(id: "t0", order: 0, minCards: 0, minXP: 0, name: text),
                DadTitle(id: "t1", order: 1, minCards: 1, minXP: 20, gearIDs: ["mug"], name: text),
                DadTitle(id: "t2", order: 1, minCards: 2, minXP: 60, name: text)
            ]))
        }
    }

    @Test("Given titles that start at 1, when validating, then invalidTitleOrder is thrown: the first is Level 0")
    func orderStartsAtZero() {
        #expect(throws: ContentDataError.invalidTitleOrder(titleID: "t1")) {
            try ContentValidator.validate(catalog([
                DadTitle(id: "t1", order: 1, minCards: 0, minXP: 0, gearIDs: ["mug"], name: text)
            ]))
        }
    }
}
