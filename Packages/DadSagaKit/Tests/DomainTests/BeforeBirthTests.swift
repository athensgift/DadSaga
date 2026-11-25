import Domain
import Foundation
import Testing

/// A child not born yet, World 0, who a card is for, retired cards and firsts before birth (ADR-0053).
@Suite("Before birth, audiences and retired cards")
struct BeforeBirthTests {
    static let text = LocalizedText(el: "x", en: "x")
    let today = CalendarDay.day(2026, 11, 21)
    let harbour = World(id: "w0", order: 0, title: text, tagline: text, span: .beforeBirth)
    let swamp = World(id: "w1", order: 1, title: text, tagline: text, span: .months(min: 0, max: 8))
    let plains = World(id: "w2", order: 2, title: text, tagline: text, span: .months(min: 9, max: nil))

    static func quest(
        _ id: String, world: String, minAge: Int = 0, evergreen: Bool = false, onlyFor: Set<Audience> = [],
        retired: Bool = false
    ) -> Quest {
        Quest(id: id, worldID: world, title: text, description: text, skill: .care, xp: 25, minAgeMonths: minAge,
              isEvergreen: evergreen, onlyFor: onlyFor, isRetired: retired)
    }

    static func boss(_ id: String, world: String, minAge: Int = 0, onlyFor: Set<Audience> = []) -> BossFight {
        BossFight(id: id, worldID: world, title: text, intro: text, guide: [text], badge: text, skill: .care, xp: 100,
                  minAgeMonths: minAge, onlyFor: onlyFor)
    }

    static func first(_ id: String, order: Int, beforeBirth: Bool = false, retired: Bool = false) -> FirstMoment {
        FirstMoment(id: id, order: order, emoji: "✨", title: text, xp: 30, companionTrait: nil,
                    isBeforeBirth: beforeBirth, isRetired: retired)
    }

    var catalog: ContentCatalog {
        ContentCatalog(
            worlds: [plains, swamp, harbour],
            quests: [
                Self.quest("q-w0-talk", world: "w0", onlyFor: [.partner]),
                Self.quest("q-w0-aid", world: "w0", evergreen: true),
                Self.quest("q-w1-feed", world: "w1"),
                Self.quest("q-w1-crew", world: "w1", onlyFor: [.olderSibling]),
                Self.quest("q-w1-date", world: "w1", minAge: 4, onlyFor: [.partner]),
                Self.quest("q-w1-tummy", world: "w1", retired: true)
            ],
            bosses: [
                Self.boss("b-w0-birth", world: "w0"),
                Self.boss("b-w1-fever", world: "w1"),
                Self.boss("b-w2-roommate", world: "w2", minAge: 25, onlyFor: [.youngerSibling])
            ],
            firsts: [
                Self.first("f-found-out", order: 1, beforeBirth: true),
                Self.first("f-picture", order: 2, beforeBirth: true),
                Self.first("f-smile", order: 3),
                Self.first("f-sleepover", order: 4, retired: true)
            ]
        )
    }

    // MARK: - Age

    @Test("Given a child not born yet, when asking the age on any day, then it is before birth")
    func notBornIsBeforeBirth() {
        let child = Child(name: "Μπέμπης", birthDay: nil)
        #expect(!child.isBorn)
        #expect(child.age(on: today) == .beforeBirth)
        #expect(child.age(on: .day(2040, 1, 1)) == .beforeBirth)
        #expect(child.day(atMonths: 0) == nil)
    }

    @Test("Given a born child, when asking the age before, on and after the birth day, then before birth, 0 and the months")
    func bornChildAge() {
        let child = Child(name: "Άννα", birthDay: .day(2026, 3, 15))
        #expect(child.age(on: .day(2026, 3, 14)) == .beforeBirth)
        #expect(child.age(on: .day(2026, 3, 15)) == .months(0))
        #expect(child.age(on: .day(2026, 5, 15)) == .months(2))
    }

    // MARK: - Worlds

    @Test("Given a child not born yet, when unlocking, then World 0 is current and the only one, with its own cards")
    func notBornHasWorldZero() {
        let family = FamilyFacts.everyone
        #expect(UnlockRules.reachedWorlds(in: catalog, age: .beforeBirth).map(\.id) == ["w0"])
        #expect(UnlockRules.currentWorld(in: catalog, age: .beforeBirth)?.id == "w0")
        #expect(!UnlockRules.isBeyondContent(catalog, age: .beforeBirth))
        #expect(UnlockRules.quests(for: harbour, in: catalog, age: .beforeBirth, family: family).map(\.id)
            == ["q-w0-talk", "q-w0-aid"])
        #expect(UnlockRules.bosses(for: harbour, in: catalog, age: .beforeBirth, family: family).map(\.id)
            == ["b-w0-birth"])
        // World 1 lies ahead, open all the same: its own cards come too (ADR-0061 §3).
        #expect(UnlockRules.isAhead(swamp, at: .beforeBirth))
        #expect(UnlockRules.quests(for: swamp, in: catalog, age: .beforeBirth, family: family).contains { $0.worldID == "w1" })
    }

    @Test("Given a child born today, when unlocking, then World 1 is current, World 0 visited, only evergreen W0 cards follow")
    func bornTodayMovesOn() {
        let family = FamilyFacts.everyone
        #expect(UnlockRules.reachedWorlds(in: catalog, age: .months(0)).map(\.id) == ["w0", "w1"])
        #expect(UnlockRules.currentWorld(in: catalog, age: .months(0))?.id == "w1")
        #expect(UnlockRules.quests(for: harbour, in: catalog, age: .months(0), family: family).map(\.id)
            == ["q-w0-talk", "q-w0-aid"])
        #expect(UnlockRules.quests(for: swamp, in: catalog, age: .months(0), family: family).map(\.id)
            == ["q-w1-feed", "q-w1-crew", "q-w0-aid"])
    }

    @Test("Given content without a world before birth, when a child is not born yet, then no world fits")
    func noWorldZeroIsBeyondContent() {
        let catalog = ContentCatalog(worlds: [swamp, plains], quests: [], bosses: [], firsts: [])
        #expect(UnlockRules.isBeyondContent(catalog, age: .beforeBirth))
        #expect(UnlockRules.currentWorld(in: catalog, age: .beforeBirth) == nil)
    }

    // MARK: - Who a card is for

    @Test("Given partner cards, when the dad has no partner, then they are gone; with one, they are back")
    func partnerCards() {
        let alone = FamilyFacts(hasPartner: false, hasOlderSibling: false, hasYoungerSibling: false)
        let together = FamilyFacts(hasPartner: true, hasOlderSibling: false, hasYoungerSibling: false)
        #expect(UnlockRules.quests(for: swamp, in: catalog, age: .months(5), family: alone).map(\.id)
            == ["q-w1-feed", "q-w0-aid"])
        #expect(UnlockRules.quests(for: swamp, in: catalog, age: .months(5), family: together).map(\.id)
            == ["q-w1-feed", "q-w1-date", "q-w0-aid"])
    }

    @Test("Given two children, when reading the facts, then the second-born has an older sibling and the first a younger one")
    func siblingsByBirthDay() {
        let first = Child(name: "Α", birthDay: .day(2023, 1, 1))
        let second = Child(name: "Β", birthDay: .day(2025, 6, 1))
        let profile = PlayerProfile(children: [first, second], heroClassID: "h")
        #expect(FamilyFacts(profile: profile, child: second).hasOlderSibling)
        #expect(!FamilyFacts(profile: profile, child: second).hasYoungerSibling)
        #expect(!FamilyFacts(profile: profile, child: first).hasOlderSibling)
        #expect(FamilyFacts(profile: profile, child: first).hasYoungerSibling)
    }

    @Test("Given twins, when reading the facts, then neither has an older or younger sibling")
    func twinsHaveNone() {
        let one = Child(name: "Α", birthDay: .day(2025, 6, 1))
        let two = Child(name: "Β", birthDay: .day(2025, 6, 1))
        let facts = FamilyFacts(profile: PlayerProfile(children: [one, two], heroClassID: "h"), child: one)
        #expect(!facts.hasOlderSibling && !facts.hasYoungerSibling)
    }

    @Test("Given a sibling on the way, then a three-year-old gets The New Roommate; an only child doesn't")
    func siblingOnTheWay() {
        let big = Child(name: "Α", birthDay: .day(2023, 6, 1))
        let coming = Child(name: "Β", birthDay: nil)
        let withSibling = FamilyFacts(profile: PlayerProfile(children: [big, coming], heroClassID: "h"), child: big)
        let alone = FamilyFacts(profile: PlayerProfile(children: [big], heroClassID: "h"), child: big)
        let comingFacts = FamilyFacts(profile: PlayerProfile(children: [big, coming], heroClassID: "h"), child: coming)
        #expect(UnlockRules.bosses(for: plains, in: catalog, age: .months(36), family: withSibling).map(\.id)
            == ["b-w2-roommate"])
        #expect(UnlockRules.bosses(for: plains, in: catalog, age: .months(36), family: alone).isEmpty)
        #expect(comingFacts.hasOlderSibling && !comingFacts.hasYoungerSibling)
    }

    @Test("Given two children both not born yet, when reading the facts, then neither has an older or younger sibling")
    func twoNotBorn() {
        let one = Child(name: "Α", birthDay: nil)
        let two = Child(name: "Β", birthDay: nil)
        let profile = PlayerProfile(children: [one, two], heroClassID: "h")
        for child in [one, two] {
            let facts = FamilyFacts(profile: profile, child: child)
            #expect(!facts.hasOlderSibling && !facts.hasYoungerSibling)
        }
    }

    @Test("Given the profile's partner answer, when reading the facts, then it is what the dad said; a new profile reads yes")
    func partnerAnswer() {
        let child = Child(name: "Α", birthDay: nil)
        #expect(FamilyFacts(profile: PlayerProfile(children: [child], heroClassID: "h"), child: child).hasPartner)
        let alone = PlayerProfile(children: [child], heroClassID: "h", hasPartner: false)
        #expect(!FamilyFacts(profile: alone, child: child).hasPartner)
    }

    // MARK: - Retired cards and firsts

    @Test(
        "Given a retired quest, when reading any world at any age and family, then it is never offered",
        arguments: [ChildAge.beforeBirth, .months(0), .months(6), .months(30)]
    )
    func retiredNeverOffered(_ age: ChildAge) {
        let quest = Self.quest("q-w1-tummy", world: "w1", retired: true)
        #expect(!UnlockRules.isOffered(quest, in: catalog, age: age, family: .everyone))
        for world in catalog.worlds {
            #expect(!UnlockRules.quests(for: world, in: catalog, age: age, family: .everyone).map(\.id).contains(quest.id))
        }
        #expect(!UnlockRules.firsts(in: catalog, age: age).map(\.id).contains("f-sleepover"))
    }

    @Test("Given a retired quest and first done before, when counting, then the timeline, XP and the map still count them")
    func retiredStillCounts() {
        let child = UUID()
        let events = [
            ProgressEvent(kind: .quest(id: "q-w1-tummy"), childID: child, date: .distantPast),
            ProgressEvent(kind: .first(id: "f-sleepover"), childID: child, date: .distantPast)
        ]
        let progress = DadProgress(events: events, catalog: catalog)
        #expect(Timeline.entries(from: events, catalog: catalog).count == 2)
        #expect(progress.totalXP == 55)
        #expect(progress.progress(in: swamp, catalog: catalog, childID: child).questsDone == 1)
    }

    @Test("Given firsts, when not born, then only the two before birth; after the birth, every first but the retired one")
    func firstsByAge() {
        #expect(UnlockRules.firsts(in: catalog, age: .beforeBirth).map(\.id) == ["f-found-out", "f-picture"])
        #expect(UnlockRules.firsts(in: catalog, age: .months(3)).map(\.id) == ["f-found-out", "f-picture", "f-smile"])
    }

    // MARK: - Profile

    @Test("Given a first before birth, when asking its earliest day, then any day; any other first, from the birth day")
    func earliestDayOfAFirst() throws {
        let today = try #require(CalendarDay(year: 2026, month: 11, day: 25))
        let birthDay = today.adding(months: -3)
        let born = Child(name: "Λένα", birthDay: birthDay)
        let coming = Child(name: "Ίρις", birthDay: nil)
        let picture = Self.first("f-picture", order: 1, beforeBirth: true)
        let smile = Self.first("f-smile", order: 2)

        #expect(UnlockRules.earliestDay(for: picture, child: born, today: today) == nil)
        #expect(UnlockRules.earliestDay(for: picture, child: coming, today: today) == nil)
        #expect(UnlockRules.earliestDay(for: smile, child: born, today: today) == birthDay)
        // Never after today, so a day can always be picked: a child not born yet, or born on a day still to come.
        #expect(UnlockRules.earliestDay(for: smile, child: coming, today: today) == today)
        #expect(UnlockRules.earliestDay(for: smile, child: born, today: birthDay.adding(days: -1)) == birthDay.adding(days: -1))
    }

    @Test("Given a first of after the birth, when dating it, then never before the birth, unless it already is dated earlier")
    func datingAFirst() throws {
        let today = try #require(CalendarDay(year: 2026, month: 11, day: 25))
        let birthDay = today.adding(months: -3)
        let born = Child(name: "Λένα", birthDay: birthDay)
        let smile = Self.first("f-smile", order: 2)
        let early = birthDay.adding(days: -10)

        #expect(UnlockRules.canDate(smile, on: birthDay, child: born, today: today))
        #expect(!UnlockRules.canDate(smile, on: birthDay.adding(days: -1), child: born, today: today))
        #expect(UnlockRules.canDate(Self.first("f-picture", order: 1, beforeBirth: true), on: early, child: born, today: today))
        #expect(UnlockRules.canDate(smile, on: early, child: born, today: today, current: early))
        #expect(UnlockRules.canDate(smile, on: early.adding(days: 3), child: born, today: today, current: early))
        #expect(!UnlockRules.canDate(smile, on: early.adding(days: -1), child: born, today: today, current: early))
    }

    @Test("Given a child not born yet, when validating, then it is valid; a born child dated tomorrow is not")
    func profileRules() throws {
        let coming = Child(name: " Μπέμπης ", birthDay: nil)
        let valid = try ProfileRules.validated(FamilyEdit(added: [coming]), for: [], on: today).added
        #expect(valid.first?.name == "Μπέμπης")
        #expect(valid.first?.birthDay == nil)
        #expect(throws: ProfileValidationError.birthDateInFuture) {
            try ProfileRules.validated(
                FamilyEdit(added: [Child(name: "Α", birthDay: today.adding(days: 1))]), for: [], on: today
            )
        }
    }
}
