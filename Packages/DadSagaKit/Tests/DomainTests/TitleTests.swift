import Domain
import Foundation
import Testing

/// Titles from cards done and XP, never lowered, bringing the hero's gear (ADR-0055).
@Suite("Titles")
struct TitleTests {
    static let text = Fixtures.text
    static let child = UUID()
    /// The owner's thresholds, with one quest of 20 care XP and a boss of 100.
    static let titles = [
        (0, 0, [String]()), (1, 20, ["g-mug"]), (2, 60, ["g-burp-cloth"]), (4, 140, ["g-duck"]),
        (7, 260, ["g-diaper-bag"]), (11, 420, ["g-blocks"]), (16, 620, ["g-thermos"]), (22, 860, ["g-mega-bag"]),
        (29, 1140, ["g-burp-cloth-gold"]), (37, 1460, [])
    ].enumerated().map { order, title in
        DadTitle(id: "t\(order)", order: order, minCards: title.0, minXP: title.1, gearIDs: title.2, name: text)
    }
    static let catalog = ContentCatalog(
        worlds: [World(id: "w1", order: 1, title: text, tagline: text, span: .months(min: 0, max: 24))],
        quests: [Quest(id: "q", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0)],
        bosses: [
            BossFight(id: "b", worldID: "w1", title: text, intro: text, guide: [], badge: text, skill: .care, xp: 100,
                      minAgeMonths: 0),
            BossFight(id: "b2", worldID: "w1", title: text, intro: text, guide: [], badge: text, skill: .care, xp: 100,
                      minAgeMonths: 0)
        ],
        firsts: [],
        gear: [
            GearItem(id: "g-burp-cloth", skill: .care, skillXPBeforeTitles: 50, look: "burpCloth", title: text),
            GearItem(id: "g-burp-cloth-gold", skill: .care, skillXPBeforeTitles: 200, look: "burpClothGold", title: text),
            GearItem(id: "g-mug", skill: .patience, skillXPBeforeTitles: 50, look: "mug", title: text),
            GearItem(id: "g-thermos", skill: .patience, skillXPBeforeTitles: 200, look: "thermos", title: text),
            GearItem(id: "g-duck", skill: .play, skillXPBeforeTitles: 50, look: "duck", title: text),
            GearItem(id: "g-blocks", skill: .play, skillXPBeforeTitles: 200, look: "blocks", title: text),
            GearItem(id: "g-diaper-bag", skill: .resilience, skillXPBeforeTitles: 50, look: "diaperBag", title: text),
            GearItem(id: "g-mega-bag", skill: .resilience, skillXPBeforeTitles: 200, look: "megaBag", title: text)
        ],
        titles: titles
    )

    static func progress(quests: Int = 0, bosses: [String] = []) -> DadProgress {
        let events = (0..<quests).map { _ in ProgressEvent(kind: .quest(id: "q"), childID: child, date: .now) }
            + bosses.map { ProgressEvent(kind: .boss(id: $0), childID: child, date: .now) }
        return DadProgress(events: events, catalog: catalog)
    }

    @Test("Given one 100 XP boss and nothing else, when reaching a title, then it is only the first after waiting")
    func anEarlyBossSkipsNothing() {
        #expect(TitleRules.reached(cardsDone: 1, xp: 100, in: Self.titles)?.order == 1)
    }

    @Test(
        "Given cards or XP alone, when reaching a title, then both are needed",
        arguments: [(1, 59, 1), (6, 1000, 3), (100, 259, 3), (37, 1460, 9), (0, 0, 0)]
    )
    func bothAreNeeded(cards: Int, xp: Int, order: Int) {
        #expect(TitleRules.reached(cardsDone: cards, xp: xp, in: Self.titles)?.order == order)
    }

    @Test("Given a quest done three times and a boss, when counting cards, then each quest counts and the boss once")
    func cardsDone() {
        let events = (0..<3).map { _ in ProgressEvent(kind: .quest(id: "q"), childID: Self.child, date: .now) }
            + [ProgressEvent(kind: .boss(id: "b"), childID: Self.child, date: .now),
               ProgressEvent(kind: .boss(id: "b"), childID: Self.child, date: .now),
               ProgressEvent(kind: .quest(id: "unknown"), childID: Self.child, date: .now)]
        #expect(DadProgress(events: events, catalog: Self.catalog).cardsDone == 4)
    }

    @Test("Given a kept title above what the entries reach, when reading the standing, then the kept one is his")
    func keptTitleWins() {
        let standing = DadStanding(
            progress: Self.progress(quests: 1), catalog: Self.catalog, kept: KeptStanding(titleID: "t3", gearIDs: [])
        )
        #expect(standing.title?.id == "t3")
        #expect(standing.gear.map(\.id) == ["g-burp-cloth", "g-duck", "g-mug"])
    }

    @Test("Given a kept title below what the entries reach, or one the content doesn't know, then the entries' title is his")
    func derivedTitleWins() {
        let higher = DadStanding(
            progress: Self.progress(quests: 13), catalog: Self.catalog, kept: KeptStanding(titleID: "t1", gearIDs: [])
        )
        let unknown = DadStanding(
            progress: Self.progress(quests: 1), catalog: Self.catalog, kept: KeptStanding(titleID: "gone", gearIDs: [])
        )
        #expect(higher.title?.id == "t4")
        #expect(unknown.title?.id == "t1")
    }

    @Test("Given a store from before titles, when not frozen yet, then the old rule reads the entries")
    func oldRuleBeforeFreezing() {
        let standing = DadStanding(progress: Self.progress(bosses: ["b"]), catalog: Self.catalog, kept: KeptStanding())
        #expect(standing.title?.id == "t1")
        #expect(standing.gear.map(\.id) == ["g-burp-cloth", "g-mug"])
        // Before a recording only the old gear is frozen: the title is kept before a deletion alone, so an Undo
        // can still take back the one a card brings.
        #expect(standing.toKeepBeforeRecording == KeptStanding(gearIDs: ["g-burp-cloth"]))
        #expect(standing.toKeepBeforeDeleting == KeptStanding(titleID: "t1", gearIDs: ["g-burp-cloth"]))
    }

    @Test("Given old gear frozen, when the skill XP would earn more, then only the frozen items stay")
    func frozenGearStays() {
        let kept = KeptStanding(titleID: "t2", gearIDs: ["g-burp-cloth"])
        let standing = DadStanding(progress: Self.progress(bosses: ["b", "b2"]), catalog: Self.catalog, kept: kept)
        #expect(standing.gear.map(\.id) == ["g-burp-cloth", "g-mug"])
        #expect(standing.toKeepBeforeRecording == nil)
        #expect(standing.toKeepBeforeDeleting == nil)
    }

    @Test("Given a saga begun with titles, when a card brings a title, then only a deletion keeps it")
    func onlyADeletionKeepsTheTitle() {
        let standing = DadStanding(progress: Self.progress(quests: 3), catalog: Self.catalog, kept: .fresh)
        #expect(standing.title?.id == "t2")
        #expect(standing.toKeepBeforeRecording == nil)
        #expect(standing.toKeepBeforeDeleting == KeptStanding(titleID: "t2", gearIDs: []))
    }

    /// The dad once an Undo has taken an entry back, and the title his closed card should go back to, if any.
    struct AfterUndo: Sendable {
        let quests: Int
        var keptTitle: String?
        var seen: String?
        var goesBackTo: String?
    }

    @Test(
        "Given a closed card, when an Undo has taken an entry back, then it goes back only to the title still held",
        arguments: [
            // The card of the title the Undo took: back to the title he holds, so it comes again.
            AfterUndo(quests: 1, seen: "t2", goesBackTo: "t1"),
            // A jump of two titles closed as one card, then undone to the lower: that one stays closed.
            AfterUndo(quests: 3, seen: "t3", goesBackTo: "t2"),
            // Closed for a title he still holds, by his entries or by what a deletion kept: it stays as it is.
            AfterUndo(quests: 3, seen: "t2"),
            AfterUndo(quests: 1, keptTitle: "t2", seen: "t2"),
            AfterUndo(quests: 0, keptTitle: "t3", seen: "t2"),
            // No card closed yet, or one the content no longer knows: nothing to take back.
            AfterUndo(quests: 0),
            AfterUndo(quests: 0, seen: "gone")
        ]
    )
    func closedCardAfterAnUndo(_ dad: AfterUndo) {
        let kept = KeptStanding(titleID: dad.keptTitle, gearIDs: [], seenTitleID: dad.seen)
        let after = DadStanding(progress: Self.progress(quests: dad.quests), catalog: Self.catalog, kept: kept)
        #expect(after.seenAfterUndo?.id == dad.goesBackTo)
    }

    @Test("Given the card a title's Undo took back, when a card reaches the title again, then its card comes again")
    func cardComesAgainAfterAnUndo() throws {
        // Three quests brought t2 and its card was closed; the Undo of the third leaves t1.
        var kept = KeptStanding(gearIDs: [], seenTitleID: "t2")
        let undone = DadStanding(progress: Self.progress(quests: 2), catalog: Self.catalog, kept: kept)
        kept.seenTitleID = try #require(undone.seenAfterUndo).id
        #expect(DadStanding(progress: Self.progress(quests: 2), catalog: Self.catalog, kept: kept).news == nil)

        let again = DadStanding(progress: Self.progress(quests: 3), catalog: Self.catalog, kept: kept)
        #expect(again.news?.title.id == "t2")
        #expect(again.news?.gear.map(\.id) == ["g-burp-cloth"])
    }

    @Test("Given a jump of two titles, when making the card, then it names the higher one and both new items")
    func cardForAJump() {
        let standing = DadStanding(
            progress: Self.progress(quests: 3), catalog: Self.catalog, kept: KeptStanding(gearIDs: [], seenTitleID: "t0")
        )
        #expect(standing.news?.title.id == "t2")
        #expect(standing.news?.gear.map(\.id) == ["g-mug", "g-burp-cloth"])
    }

    @Test("Given an item the hero had before titles, when its title comes, then the card doesn't list it")
    func cardListsOnlyWhatIsNew() {
        let kept = KeptStanding(titleID: "t1", gearIDs: ["g-burp-cloth"], seenTitleID: "t1")
        let standing = DadStanding(progress: Self.progress(quests: 3), catalog: Self.catalog, kept: kept)
        #expect(standing.news?.title.id == "t2")
        #expect(standing.news?.gear.isEmpty == true)
    }

    @Test("Given the card for his title closed, when reading the standing, then there is no card")
    func noCardOnceSeen() {
        let kept = KeptStanding(gearIDs: [], seenTitleID: "t1")
        #expect(DadStanding(progress: Self.progress(quests: 1), catalog: Self.catalog, kept: kept).news == nil)
        #expect(DadStanding(progress: Self.progress(), catalog: Self.catalog, kept: .fresh).news == nil)
    }

    @Test("Given a film that ended before the dad's later cards, when reading the dad then, then it is his title then")
    func asOfAFilmsEnd() {
        let kept = KeptStanding(titleID: "t4", gearIDs: ["g-burp-cloth-gold"])
        let then = DadStanding.asOf(Self.progress(bosses: ["b"]), catalog: Self.catalog, kept: kept)
        #expect(then.title?.id == "t1")
        // The gold cloth was kept, but the old rule hadn't earned it by then (100 care XP < 200).
        #expect(then.gear.map(\.id) == ["g-mug"])
        #expect(then.news == nil)
    }
}
