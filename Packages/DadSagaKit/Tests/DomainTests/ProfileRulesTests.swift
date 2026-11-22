import Domain
import Foundation
import Testing

@Suite("ProfileRules")
struct ProfileRulesTests {
    let today = CalendarDay.day(2026, 11, 21)
    let heroes = [HeroClass(id: "h1", order: 1, title: Fixtures.text, tagline: Fixtures.text, look: "hero")]

    func child(_ name: String = "Νίκος", bornDaysAgo days: Int = 30) -> Child {
        Child(name: name, birthDay: today.adding(days: -days), gender: .girl, skinTone: .dark)
    }

    func profile(_ children: [Child]? = nil, hero: String = "h1") -> PlayerProfile {
        PlayerProfile(children: children ?? [child()], heroClassID: hero, dadSkinTone: .medium)
    }

    @Test("Given names with surrounding spaces, when validating, then every name is trimmed and the rest is kept")
    func trimsNames() throws {
        let first = child("  Νίκος \n")
        let second = child(" Άννα", bornDaysAgo: 900)
        let valid = try ProfileRules.validated(profile([first, second]), on: today, heroClasses: heroes)
        #expect(valid.children.map(\.name) == ["Νίκος", "Άννα"])
        #expect(valid.children.map(\.id) == [first.id, second.id])
        #expect(valid.children.first?.gender == .girl)
        #expect(valid.children.first?.skinTone == .dark)
        #expect(valid.dadSkinTone == .medium)
        #expect(valid.heroClassID == "h1")
    }

    @Test("Given no children, when validating, then noChildren is thrown")
    func noChildren() {
        #expect(throws: ProfileValidationError.noChildren) {
            try ProfileRules.validated(profile([]), on: today, heroClasses: heroes)
        }
    }

    @Test("Given four children stored, when validating five, then tooManyChildren is thrown")
    func tooManyChildren() {
        let five = (0..<5).map { _ in child() }
        #expect(throws: ProfileValidationError.tooManyChildren) {
            try ProfileRules.validated(profile(five), on: today, heroClasses: heroes)
        }
        #expect(throws: ProfileValidationError.tooManyChildren) {
            try ProfileRules.validatedChildren(five, on: today, storedCount: 4)
        }
    }

    @Test("Given five children stored (from a copy), when validating five or four, then they pass; six do not")
    func theLimitIsOnAddingOnly() throws {
        let five = (0..<5).map { _ in child() }
        #expect(try ProfileRules.validated(profile(five), on: today, heroClasses: heroes, storedCount: 5).children.count == 5)
        #expect(try ProfileRules.validatedChildren(Array(five.prefix(4)), on: today, storedCount: 5).count == 4)
        #expect(throws: ProfileValidationError.tooManyChildren) {
            try ProfileRules.validatedChildren(five + [child()], on: today, storedCount: 5)
        }
    }

    @Test("Given one blank name among several, when validating, then emptyChildName is thrown")
    func blankName() {
        #expect(throws: ProfileValidationError.emptyChildName) {
            try ProfileRules.validated(profile([child(), child("   ")]), on: today, heroClasses: heroes)
        }
    }

    @Test("Given a birth day after today, when validating, then birthDateInFuture is thrown; today itself is fine")
    func futureBirthDate() throws {
        #expect(throws: ProfileValidationError.birthDateInFuture) {
            try ProfileRules.validated(profile([child(bornDaysAgo: -1)]), on: today, heroClasses: heroes)
        }
        let born = try ProfileRules.validated(profile([child(bornDaysAgo: 0)]), on: today, heroClasses: heroes)
        #expect(born.children.first?.birthDay == today)
    }

    @Test("Given a hero class that is not in the content, when validating, then unknownHeroClass is thrown")
    func unknownHero() {
        #expect(throws: ProfileValidationError.unknownHeroClass("nope")) {
            try ProfileRules.validated(profile(hero: "nope"), on: today, heroClasses: heroes)
        }
    }
}
