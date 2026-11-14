import Foundation
import Testing
import Domain

@Suite("LevelCurve")
struct LevelCurveTests {
    @Test("Given 0 XP, when computing level, then level is 1")
    func zeroXPIsLevelOne() {
        #expect(LevelCurve.level(forTotalXP: 0) == 1)
    }

    @Test(
        "Given XP on a level boundary, when computing level, then the new level is reached",
        arguments: [(100, 2), (299, 2), (300, 3), (600, 4), (1000, 5)]
    )
    func levelBoundaries(xp: Int, expectedLevel: Int) {
        #expect(LevelCurve.level(forTotalXP: xp) == expectedLevel)
    }

    @Test("Given 200 XP, when computing progress, then it is halfway through level 2")
    func progressInsideLevel() {
        let progress = LevelCurve.progress(forTotalXP: 200)
        #expect(progress.level == 2)
        #expect(progress.xpIntoLevel == 100)
        #expect(progress.xpNeededForNextLevel == 200)
        #expect(progress.fraction == 0.5)
    }

    @Test("Given negative XP, when computing progress, then it is clamped to level 1")
    func negativeXPIsClamped() {
        #expect(LevelCurve.progress(forTotalXP: -50) == LevelCurve.progress(forTotalXP: 0))
    }
}

@Suite("DadProgress")
struct DadProgressTests {
    let catalog = Fixtures.catalog

    @Test("Given repeated quests, when aggregating, then each completion adds XP to total and skill")
    func questsAreRepeatable() {
        let events = [Fixtures.event(.quest(id: "q1")), Fixtures.event(.quest(id: "q1"))]
        let progress = DadProgress(events: events, catalog: catalog)
        #expect(progress.totalXP == 40)
        #expect(progress.skillXP[.care] == 40)
        #expect(progress.questCompletions(for: nil) == ["q1": 2])
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

    @Test("Given a boss defeated twice, when aggregating, then XP is counted once")
    func bossCountsOnce() {
        let events = [Fixtures.event(.boss(id: "b1")), Fixtures.event(.boss(id: "b1"))]
        let progress = DadProgress(events: events, catalog: catalog)
        #expect(progress.totalXP == 100)
        #expect(progress.defeatedBossIDs(for: nil) == ["b1"])
    }

    @Test("Given a first captured twice, when aggregating, then XP is counted once and no skill gets XP")
    func firstCountsOnceWithoutSkill() {
        let events = [Fixtures.event(.first(id: "f1")), Fixtures.event(.first(id: "f1"))]
        let progress = DadProgress(events: events, catalog: catalog)
        #expect(progress.totalXP == 30)
        #expect(progress.skillXP.isEmpty)
        #expect(progress.capturedFirstIDs(for: nil) == ["f1"])
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
    func newborn() {
        #expect(UnlockRules.unlockedWorlds(in: catalog, ageInMonths: 0).map(\.id) == ["w1"])
        #expect(UnlockRules.availableQuests(in: catalog, ageInMonths: 0).map(\.id) == ["q1"])
        #expect(UnlockRules.availableBosses(in: catalog, ageInMonths: 0).map(\.id) == ["b1"])
    }

    @Test("Given a 10-month-old, when unlocking, then both worlds are open and the current world is the second")
    func tenMonths() {
        #expect(UnlockRules.unlockedWorlds(in: catalog, ageInMonths: 10).count == 2)
        #expect(UnlockRules.currentWorld(in: catalog, ageInMonths: 10)?.id == "w2")
        #expect(Set(UnlockRules.availableQuests(in: catalog, ageInMonths: 10).map(\.id)) == ["q1", "q2", "q3"])
    }
}

@Suite("Child")
struct ChildTests {
    @Test("Given a birth date, when computing age, then completed months are returned and never negative")
    func ageInMonths() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let birth = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 15)))
        let child = Child(name: "Νίκος", birthDate: birth)

        let dayBefore = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 14)))
        let onTheDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 15)))
        let beforeBirth = try #require(calendar.date(from: DateComponents(year: 2025, month: 12, day: 1)))

        #expect(child.ageInMonths(at: dayBefore, calendar: calendar) == 2)
        #expect(child.ageInMonths(at: onTheDay, calendar: calendar) == 3)
        #expect(child.ageInMonths(at: beforeBirth, calendar: calendar) == 0)
    }
}

enum Fixtures {
    static let text = LocalizedText(el: "x", en: "x")

    static let catalog = ContentCatalog(
        worlds: [
            World(id: "w2", order: 2, title: text, tagline: text, minAgeMonths: 9, maxAgeMonths: 24),
            World(id: "w1", order: 1, title: text, tagline: text, minAgeMonths: 0, maxAgeMonths: 8)
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

    static func event(_ kind: ProgressEvent.Kind, child: UUID? = nil) -> ProgressEvent {
        ProgressEvent(kind: kind, childID: child, date: Date(timeIntervalSince1970: 0))
    }
}
