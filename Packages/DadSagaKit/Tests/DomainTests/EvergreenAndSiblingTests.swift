import Domain
import Foundation
import Testing

@Suite("UnlockRules, evergreen quests and sibling-only bosses")
struct EvergreenAndSiblingTests {
    static let text = LocalizedText(el: "x", en: "x")

    static func quest(_ id: String, world: String, minAge: Int, evergreen: Bool = false) -> Quest {
        Quest(id: id, worldID: world, title: text, description: text, skill: .care, xp: 10, minAgeMonths: minAge,
              isEvergreen: evergreen)
    }

    static func boss(_ id: String, sibling: Bool = false) -> BossFight {
        BossFight(id: id, worldID: "w1", title: text, intro: text, guide: [text], badge: text, skill: .care, xp: 100,
                  minAgeMonths: 0, requiresSibling: sibling)
    }

    let first = World(id: "w1", order: 1, title: text, tagline: text, minAgeMonths: 0, maxAgeMonths: 8)
    let second = World(id: "w2", order: 2, title: text, tagline: text, minAgeMonths: 9, maxAgeMonths: 24)
    let third = World(id: "w3", order: 3, title: text, tagline: text, minAgeMonths: 25, maxAgeMonths: nil)

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
            bosses: [Self.boss("b-plain"), Self.boss("b-sibling", sibling: true)],
            firsts: []
        )
    }

    @Test("Given an evergreen quest, when showing a later world, then it follows that world's own quests")
    func evergreenShowsLater() {
        let ids = UnlockRules.quests(for: third, in: catalog, ageInMonths: 26).map(\.id)
        #expect(ids == ["w3-own", "w3-ever", "w1-ever", "w2-ever"])
    }

    @Test("Given an evergreen quest, when showing its own or an earlier world, then it appears only once and not earlier")
    func evergreenStaysInPlace() {
        #expect(UnlockRules.quests(for: first, in: catalog, ageInMonths: 26).map(\.id) == ["w1-plain", "w1-ever"])
        #expect(UnlockRules.quests(for: second, in: catalog, ageInMonths: 26).map(\.id) == ["w2-own", "w2-ever", "w1-ever"])
    }

    @Test("Given an evergreen quest with a later minimum age, when the child is younger, then it is not shown")
    func evergreenRespectsMinimumAge() {
        #expect(!UnlockRules.quests(for: third, in: catalog, ageInMonths: 26).map(\.id).contains("w1-late"))
        #expect(UnlockRules.quests(for: third, in: catalog, ageInMonths: 30).map(\.id).contains("w1-late"))
    }

    @Test("Given a sibling-only boss, when the family has one child, then it is hidden")
    func siblingBossHiddenForOneChild() {
        let ids = UnlockRules.availableBosses(in: catalog, ageInMonths: 0, childCount: 1).map(\.id)
        #expect(ids == ["b-plain"])
    }

    @Test("Given a sibling-only boss, when the family has two children, then it is shown")
    func siblingBossShownForTwoChildren() {
        let ids = UnlockRules.availableBosses(in: catalog, ageInMonths: 0, childCount: 2).map(\.id)
        #expect(ids == ["b-plain", "b-sibling"])
    }

    @Test("Given evergreen quests done in a later world and a sibling boss, when counting a world, then only its own count")
    func worldProgressCountsOwnContent() {
        let child = UUID()
        let events = ["w1-ever", "w1-plain", "w1-plain", "w2-own"].map {
            ProgressEvent(kind: .quest(id: $0), childID: child, date: .distantPast)
        } + ["b-plain", "b-sibling"].map { ProgressEvent(kind: .boss(id: $0), childID: child, date: .distantPast) }
        let progress = DadProgress(events: events, catalog: catalog)

        let alone = progress.progress(in: first, catalog: catalog, childID: child, childCount: 1)
        let withSibling = progress.progress(in: first, catalog: catalog, childID: child, childCount: 2)
        let other = progress.progress(in: first, catalog: catalog, childID: UUID(), childCount: 1)

        #expect(alone == WorldProgress(questsDone: 2, bossesDone: 1))
        #expect(withSibling == WorldProgress(questsDone: 2, bossesDone: 2))
        #expect(other == WorldProgress(questsDone: 0, bossesDone: 0))
    }
}
