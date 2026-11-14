import Domain
import Foundation
import Testing

@Suite("ProfileRules")
struct ProfileRulesTests {
    let today = Date(timeIntervalSince1970: 1_000_000)
    let heroes = [HeroClass(id: "h1", order: 1, title: Fixtures.text, tagline: Fixtures.text)]

    func child(_ name: String = "Νίκος", bornDaysAgo days: Double = 30) -> Child {
        Child(name: name, birthDate: today.addingTimeInterval(-days * 86_400), gender: .girl, skinTone: .dark)
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

    @Test("Given five children, when validating, then tooManyChildren is thrown")
    func tooManyChildren() {
        #expect(throws: ProfileValidationError.tooManyChildren) {
            try ProfileRules.validated(profile((0..<5).map { _ in child() }), on: today, heroClasses: heroes)
        }
    }

    @Test("Given one blank name among several, when validating, then emptyChildName is thrown")
    func blankName() {
        #expect(throws: ProfileValidationError.emptyChildName) {
            try ProfileRules.validated(profile([child(), child("   ")]), on: today, heroClasses: heroes)
        }
    }

    @Test("Given a birth date after today, when validating, then birthDateInFuture is thrown")
    func futureBirthDate() {
        #expect(throws: ProfileValidationError.birthDateInFuture) {
            try ProfileRules.validated(profile([child(bornDaysAgo: -1)]), on: today, heroClasses: heroes)
        }
    }

    @Test("Given a hero class that is not in the content, when validating, then unknownHeroClass is thrown")
    func unknownHero() {
        #expect(throws: ProfileValidationError.unknownHeroClass("nope")) {
            try ProfileRules.validated(profile(hero: "nope"), on: today, heroClasses: heroes)
        }
    }
}
