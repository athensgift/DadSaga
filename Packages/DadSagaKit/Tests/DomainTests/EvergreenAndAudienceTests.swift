import Domain
import Foundation
import Testing

@Suite("UnlockRules, evergreen cards and who a card is for")
struct EvergreenAndAudienceTests {
    static let text = LocalizedText(el: "x", en: "x")

    static func quest(_ id: String, world: String, minAge: Int, evergreen: Bool = false) -> Quest {
        Quest(id: id, worldID: world, title: text, description: text, skill: .care, xp: 10, minAgeMonths: minAge,
              isEvergreen: evergreen)
    }

    static func boss(
        _ id: String,
        world: String = "w1",
        minAge: Int = 0,
        onlyFor: Set<Audience> = [],
        evergreen: Bool = false
    ) -> BossFight {
        BossFight(id: id, worldID: world, title: text, intro: text, guide: [text], badge: text, skill: .care, xp: 100,
                  minAgeMonths: minAge, onlyFor: onlyFor, isEvergreen: evergreen)
    }

    let first = World(id: "w1", order: 1, title: text, tagline: text, span: .months(min: 0, max: 8))
    let second = World(id: "w2", order: 2, title: text, tagline: text, span: .months(min: 9, max: 24))
    let third = World(id: "w3", order: 3, title: text, tagline: text, span: .months(min: 25, max: nil))

    var catalog: ContentCatalog {
        ContentCatalog(
            worlds: [third, first, second],
            quests: [
                Self.quest("w2-own", world: "w2", minAge: 9),
                Self.quest("w1-plain", world: "w1", minAge: 0),
                Self.quest("w1-late", world: "w1", minAge: 30, evergreen: true),
                Self.quest("w2-ever", world: "w2", minAge: 9, evergreen: true),
                Self.quest("w1-ever", world: "w1", minAge: 0, evergreen: true),
                Self.quest("w3-own", world: "w3", minAge: 25),
                Self.quest("w3-ever", world: "w3", minAge: 25, evergreen: true)
            ],
            bosses: [
                Self.boss("b-plain"),
                Self.boss("b-younger", onlyFor: [.youngerSibling]),
                Self.boss("b-ever", evergreen: true),
                Self.boss("b-w2", world: "w2", minAge: 9)
            ],
            firsts: []
        )
    }

    @Test("Given an evergreen quest, when showing a later world, then it follows that world's own quests")
    func evergreenShowsLater() {
        let ids = UnlockRules.quests(for: third, in: catalog, age: .months(26), family: .everyone).map(\.id)
        #expect(ids == ["w3-own", "w3-ever", "w1-ever", "w2-ever"])
    }

    @Test("Given an evergreen quest, when showing its own or an earlier world, then it appears only once and not earlier")
    func evergreenStaysInPlace() {
        #expect(UnlockRules.quests(for: first, in: catalog, age: .months(26), family: .everyone).map(\.id)
            == ["w1-plain", "w1-ever"])
        #expect(UnlockRules.quests(for: second, in: catalog, age: .months(26), family: .everyone).map(\.id)
            == ["w2-own", "w2-ever", "w1-ever"])
    }

    @Test("Given an evergreen quest with a later minimum age, when the child is younger, then it is not shown")
    func evergreenRespectsMinimumAge() {
        #expect(!UnlockRules.quests(for: third, in: catalog, age: .months(26), family: .everyone).map(\.id)
            .contains("w1-late"))
        #expect(UnlockRules.quests(for: third, in: catalog, age: .months(30), family: .everyone).map(\.id)
            .contains("w1-late"))
    }

    @Test("Given an evergreen boss, when showing later worlds, then it follows their own bosses; not in an earlier world")
    func evergreenBossShowsLater() {
        let family = FamilyFacts.everyone
        #expect(UnlockRules.bosses(for: second, in: catalog, age: .months(10), family: family).map(\.id)
            == ["b-w2", "b-ever"])
        #expect(UnlockRules.bosses(for: third, in: catalog, age: .months(30), family: family).map(\.id) == ["b-ever"])
        #expect(UnlockRules.bosses(for: first, in: catalog, age: .months(30), family: family).map(\.id)
            == ["b-plain", "b-younger", "b-ever"])
    }

    @Test("Given a boss for a child with a younger sibling, when the family has none, then it is not offered")
    func audienceBossHidden() {
        let family = FamilyFacts(hasPartner: true, hasOlderSibling: true, hasYoungerSibling: false)
        let ids = UnlockRules.bosses(for: first, in: catalog, age: .months(0), family: family).map(\.id)
        #expect(ids == ["b-plain", "b-ever"])
    }

    @Test("Given bosses beaten, evergreen or now for someone else, when counting a world, then each counts in its own world")
    func worldProgressCountsEveryBossBeaten() {
        let child = UUID()
        let events = ["w1-ever", "w1-plain", "w1-plain", "w2-own"].map {
            ProgressEvent(kind: .quest(id: $0), childID: child, date: .distantPast)
        } + ["b-plain", "b-younger", "b-ever"].map {
            ProgressEvent(kind: .boss(id: $0), childID: child, date: .distantPast)
        }
        let progress = DadProgress(events: events, catalog: catalog)

        #expect(progress.progress(in: first, catalog: catalog, childID: child)
            == WorldProgress(questsDone: 2, bossesDone: 3))
        #expect(progress.progress(in: second, catalog: catalog, childID: child)
            == WorldProgress(questsDone: 1, bossesDone: 0))
        #expect(progress.progress(in: first, catalog: catalog, childID: UUID()) == WorldProgress(questsDone: 0, bossesDone: 0))
    }
}
