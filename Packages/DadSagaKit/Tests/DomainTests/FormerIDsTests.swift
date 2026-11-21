import Domain
import Foundation
import Testing

/// A renamed card keeps everything the dad recorded under its old id (ADR-0048 §5).
@Suite("Former ids")
struct FormerIDsTests {
    static let text = Fixtures.text
    let anna = UUID()

    let catalog = ContentCatalog(
        worlds: [
            World(id: "w1", order: 1, title: text, tagline: text, minAgeMonths: 0, maxAgeMonths: 8)
        ],
        quests: [
            Quest(
                id: "q-new", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0,
                formerIDs: ["q-old"]
            )
        ],
        bosses: [
            BossFight(
                id: "b-new", worldID: "w1", title: text, intro: text, guide: [text], badge: text, skill: .patience,
                xp: 100, minAgeMonths: 0, formerIDs: ["b-old"]
            )
        ],
        firsts: [
            FirstMoment(id: "f-new", order: 1, emoji: "😊", title: text, xp: 30, companionTrait: nil, formerIDs: ["f-old"])
        ],
        heroClasses: [
            HeroClass(id: "h1", order: 1, title: text, tagline: text, look: "hero"),
            HeroClass(id: "h2", order: 2, title: text, tagline: text, look: "chef", formerIDs: ["h-old"])
        ],
        gear: [
            GearItem(id: "mug", skill: .care, minXP: 10, look: "mug", title: text),
            GearItem(id: "cloth", skill: .care, minXP: 20, look: "burpCloth", title: text, formerIDs: ["rag"])
        ]
    )

    func event(_ kind: ProgressEvent.Kind, at seconds: TimeInterval = 0) -> ProgressEvent {
        ProgressEvent(kind: kind, childID: anna, date: Date(timeIntervalSince1970: seconds))
    }

    @Test("Given a quest done before it was renamed, when counting, then its XP and the quest are still the dad's")
    func renamedQuestKeepsItsXP() throws {
        let progress = DadProgress(events: [event(.quest(id: "q-old"))], catalog: catalog)

        #expect(progress.totalXP == 20)
        #expect(progress.skillXP[.care] == 20)
        #expect(progress.questCompletions(for: anna) == ["q-new": 1])
        let entry = try #require(Timeline.entries(from: [event(.quest(id: "q-old"))], catalog: catalog).first)
        #expect(entry.kind == .quest(catalog.quests[0]))
    }

    @Test("Given a boss beaten under its old id and again under the new one, when counting, then it counts once")
    func renamedBossCountsOnce() {
        let events = [event(.boss(id: "b-old"), at: 1), event(.boss(id: "b-new"), at: 2)]

        let progress = DadProgress(events: events, catalog: catalog)

        #expect(progress.totalXP == 100)
        #expect(progress.defeatedBossIDs(for: anna) == ["b-new"])
        #expect(progress.isAlreadyCounted(.boss(id: "b-new"), for: anna))
        #expect(Timeline.entries(from: events, catalog: catalog).count == 1)
    }

    @Test("Given a first captured before it was renamed, when reading the moments, then it is still there")
    func renamedFirstStaysAMoment() {
        let progress = DadProgress(events: [event(.first(id: "f-old"))], catalog: catalog)

        #expect(progress.moments(for: anna).map(\.first.id) == ["f-new"])
        #expect(progress.capturedFirstIDs(for: anna) == ["f-new"])
    }

    @Test("Given an item chosen before it was renamed, when dressing the hero, then it is still worn")
    func renamedGearStaysWorn() {
        let worn = GearRules.equipped(
            catalog.gear, skillXP: [.care: 30], outfit: Outfit(choices: [.care: .item("rag")])
        )

        #expect(worn.map(\.id) == ["cloth"])
    }

    @Test("Given a world's film offer answered before the world was renamed, when it shows again, then nothing is offered")
    func renamedWorldKeepsItsAnswer() throws {
        let text = Self.text
        let saga = SagaFixtures(worlds: [
            World(id: "w1-new", order: 1, title: text, tagline: text, minAgeMonths: 0, maxAgeMonths: 8, formerIDs: ["w1"]),
            World(id: "w2", order: 2, title: text, tagline: text, minAgeMonths: 9, maxAgeMonths: nil)
        ])
        let events = [saga.event(.quest(id: "q1"), months: 3)]
        let offered = try #require(saga.occasion(events, months: 9))
        #expect(offered.period == .world(id: "w1-new"))

        let answeredBefore = "\(saga.child.id.uuidString)/world/w1"
        #expect(saga.occasion(events, months: 9, answered: [answeredBefore]) == nil)
    }

    @Test("Given this week's quest done under its old id, when checking the week, then it is done")
    func weeklyQuestDoneUnderFormerID() {
        let week = DateInterval(start: Date(timeIntervalSince1970: 0), duration: 7 * 24 * 60 * 60)

        let done = WeeklyQuest.isDone(
            catalog.quests[0], childID: anna, week: week, events: [event(.quest(id: "q-old"), at: 60)]
        )

        #expect(done)
    }

    @Test("Given a hero id the content no longer has, when finding the dad's hero, then it is the first one")
    func unknownHeroShowsAsTheFirst() {
        let child = Child(name: "Άννα", birthDay: .day(2025, 3, 15))

        #expect(catalog.hero(for: PlayerProfile(children: [child], heroClassID: "gone"))?.id == "h1")
        #expect(catalog.hero(for: PlayerProfile(children: [child], heroClassID: "h-old"))?.id == "h2")
    }
}
