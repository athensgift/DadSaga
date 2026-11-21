import Foundation
import Testing
import Domain

@Suite("DadProgress")
struct DadProgressTests {
    let catalog = Fixtures.catalog

    @Test("Given repeated quests, when aggregating, then each completion adds XP to total and skill")
    func questsAreRepeatable() {
        let events = [Fixtures.event(.quest(id: "q1")), Fixtures.event(.quest(id: "q1"))]
        let progress = DadProgress(events: events, catalog: catalog)
        #expect(progress.totalXP == 40)
        #expect(progress.skillXP[.care] == 40)
        #expect(progress.questCompletions(for: Fixtures.child) == ["q1": 2])
    }

    @Test("Given two children, when aggregating, then XP is shared but quests, bosses and firsts are kept per child")
    func perChild() {
        let anna = UUID()
        let niko = UUID()
        let events = [
            Fixtures.event(.quest(id: "q1"), child: anna),
            Fixtures.event(.boss(id: "b1"), child: anna),
            Fixtures.event(.boss(id: "b1"), child: niko),
            Fixtures.event(.first(id: "f1"), child: niko)
        ]
        let progress = DadProgress(events: events, catalog: catalog)
        #expect(progress.totalXP == 20 + 100 + 100 + 30)
        #expect(progress.questCompletions(for: anna) == ["q1": 1])
        #expect(progress.questCompletions(for: niko).isEmpty)
        #expect(progress.defeatedBossIDs(for: anna) == ["b1"])
        #expect(progress.defeatedBossIDs(for: niko) == ["b1"])
        #expect(progress.capturedFirstIDs(for: anna).isEmpty)
        #expect(progress.capturedFirstIDs(for: niko) == ["f1"])
        #expect(progress.allDefeatedBossIDs == ["b1"])
    }

    @Test("Given firsts captured on different days, when listing moments, then they come newest first with notes")
    func momentsNewestFirst() {
        let child = UUID()
        let catalog = ContentCatalog(
            worlds: [], quests: [], bosses: [],
            firsts: [
                FirstMoment(id: "a", order: 1, emoji: "😊", title: Fixtures.text, xp: 30, companionTrait: nil),
                FirstMoment(id: "b", order: 2, emoji: "👣", title: Fixtures.text, xp: 30, companionTrait: nil)
            ]
        )
        let events = [
            ProgressEvent(kind: .first(id: "a"), childID: child, date: Date(timeIntervalSince1970: 100), note: "πρώτο"),
            ProgressEvent(kind: .first(id: "b"), childID: child, date: Date(timeIntervalSince1970: 200))
        ]
        let moments = DadProgress(events: events, catalog: catalog).moments(for: child)
        #expect(moments.map(\.first.id) == ["b", "a"])
        #expect(moments.map(\.note) == [nil, "πρώτο"])
    }

    @Test("Given a first with three photos, when listing moments, then it carries them in order with the first as cover")
    func momentCarriesPhotos() {
        let event = ProgressEvent(
            kind: .first(id: "f1"), childID: Fixtures.child, date: .distantPast, photoIDs: ["c", "a", "b"]
        )
        let moment = DadProgress(events: [event], catalog: catalog).moments(for: Fixtures.child).first
        #expect(moment?.photoIDs == ["c", "a", "b"])
        #expect(moment?.coverPhotoID == "c")
    }

    @Test("Given a quest with photos and no note, when asking for the last journal, then the photos make one")
    func photosAloneMakeAJournalEntry() {
        let event = ProgressEvent(kind: .quest(id: "q1"), childID: Fixtures.child, date: .distantPast, photoIDs: ["a", "b"])
        let progress = DadProgress(events: [event, Fixtures.event(.quest(id: "q2"))], catalog: catalog)

        #expect(progress.lastJournal(for: .quest(id: "q1"), childID: Fixtures.child)?.photoIDs == ["a", "b"])
        #expect(progress.lastJournal(for: .quest(id: "q2"), childID: Fixtures.child) == nil)
    }

    @Test("Given a boss defeated twice, when aggregating, then XP is counted once")
    func bossCountsOnce() {
        let events = [Fixtures.event(.boss(id: "b1")), Fixtures.event(.boss(id: "b1"))]
        let progress = DadProgress(events: events, catalog: catalog)
        #expect(progress.totalXP == 100)
        #expect(progress.defeatedBossIDs(for: Fixtures.child) == ["b1"])
    }

    @Test("Given a first captured twice, when aggregating, then XP is counted once and no skill gets XP")
    func firstCountsOnceWithoutSkill() {
        let events = [Fixtures.event(.first(id: "f1")), Fixtures.event(.first(id: "f1"))]
        let progress = DadProgress(events: events, catalog: catalog)
        #expect(progress.totalXP == 30)
        #expect(progress.skillXP.isEmpty)
        #expect(progress.capturedFirstIDs(for: Fixtures.child) == ["f1"])
    }

    @Test("Given an event for removed content, when aggregating, then it is ignored")
    func unknownIDsAreIgnored() {
        let progress = DadProgress(events: [Fixtures.event(.quest(id: "gone"))], catalog: catalog)
        #expect(progress.totalXP == 0)
    }
}

@Suite("UnlockRules")
struct UnlockRulesTests {
    let catalog = Fixtures.catalog

    @Test("Given a newborn, when unlocking, then only the first world and its age-0 quests are available")
    func newborn() throws {
        #expect(UnlockRules.unlockedWorlds(in: catalog, age: .months(0)).map(\.id) == ["w1"])
        let first = try #require(catalog.worlds.first { $0.id == "w1" })
        #expect(UnlockRules.quests(for: first, in: catalog, age: .months(0), family: .everyone).map(\.id) == ["q1"])
        #expect(UnlockRules.bosses(for: first, in: catalog, age: .months(0), family: .everyone).map(\.id) == ["b1"])
    }

    @Test("Given a 10-month-old, when unlocking, then both worlds are open and the current world is the second")
    func tenMonths() throws {
        #expect(UnlockRules.unlockedWorlds(in: catalog, age: .months(10)).count == 2)
        #expect(UnlockRules.currentWorld(in: catalog, age: .months(10))?.id == "w2")
        let first = try #require(catalog.worlds.first { $0.id == "w1" })
        let second = try #require(catalog.worlds.first { $0.id == "w2" })
        #expect(UnlockRules.quests(for: first, in: catalog, age: .months(10), family: .everyone).map(\.id) == ["q1", "q2"])
        #expect(UnlockRules.quests(for: second, in: catalog, age: .months(10), family: .everyone).map(\.id) == ["q3"])
    }
}

@Suite("Child")
struct ChildTests {
    @Test("Given a birth day, when computing age, then completed months are returned, and a day before the birth is before birth")
    func ageByBirthDay() {
        let child = Child(name: "Νίκος", birthDay: .day(2026, 1, 15))

        #expect(child.age(on: .day(2026, 4, 14)).months == 2)
        #expect(child.age(on: .day(2026, 4, 15)).months == 3)
        #expect(child.age(on: .day(2025, 12, 1)) == .beforeBirth)
    }
}

enum Fixtures {
    static let text = LocalizedText(el: "x", en: "x")

    static let catalog = ContentCatalog(
        worlds: [
            World(id: "w2", order: 2, title: text, tagline: text, span: .months(min: 9, max: 24)),
            World(id: "w1", order: 1, title: text, tagline: text, span: .months(min: 0, max: 8))
        ],
        quests: [
            Quest(id: "q1", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0),
            Quest(id: "q2", worldID: "w1", title: text, description: text, skill: .play, xp: 20, minAgeMonths: 4),
            Quest(id: "q3", worldID: "w2", title: text, description: text, skill: .patience, xp: 30, minAgeMonths: 9),
            Quest(id: "q4", worldID: "w2", title: text, description: text, skill: .play, xp: 30, minAgeMonths: 15)
        ],
        bosses: [
            BossFight(id: "b1", worldID: "w1", title: text, intro: text, guide: [text], badge: text,
                      skill: .care, xp: 100, minAgeMonths: 0)
        ],
        firsts: [
            FirstMoment(id: "f1", order: 1, emoji: "😊", title: text, xp: 30, companionTrait: "smile")
        ]
    )

    /// The child an event happens with when a test doesn't name one.
    static let child = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1") ?? UUID()

    static func event(_ kind: ProgressEvent.Kind, child: UUID = Fixtures.child) -> ProgressEvent {
        ProgressEvent(kind: kind, childID: child, date: Date(timeIntervalSince1970: 0))
    }
}
