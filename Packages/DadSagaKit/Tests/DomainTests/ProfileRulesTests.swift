import Domain
import Foundation
import Testing

@Suite("ProfileRules")
struct ProfileRulesTests {
    let today = Date(timeIntervalSince1970: 1_000_000)
    let heroes = [HeroClass(id: "h1", order: 1, title: Fixtures.text, tagline: Fixtures.text)]

    func profile(name: String = "Νίκος", bornDaysAgo days: Double = 30, hero: String = "h1") -> PlayerProfile {
        PlayerProfile(child: Child(name: name, birthDate: today.addingTimeInterval(-days * 86_400)), heroClassID: hero)
    }

    @Test("Given a name with surrounding spaces, when validating, then the name is trimmed")
    func trimsName() throws {
        let valid = try ProfileRules.validated(profile(name: "  Νίκος \n"), on: today, heroClasses: heroes)
        #expect(valid.child.name == "Νίκος")
        #expect(valid.heroClassID == "h1")
    }

    @Test("Given a blank name, when validating, then emptyChildName is thrown")
    func blankName() {
        #expect(throws: ProfileValidationError.emptyChildName) {
            try ProfileRules.validated(profile(name: "   "), on: today, heroClasses: heroes)
        }
    }

    @Test("Given a birth date after today, when validating, then birthDateInFuture is thrown")
    func futureBirthDate() {
        #expect(throws: ProfileValidationError.birthDateInFuture) {
            try ProfileRules.validated(profile(bornDaysAgo: -1), on: today, heroClasses: heroes)
        }
    }

    @Test("Given a hero class that is not in the content, when validating, then unknownHeroClass is thrown")
    func unknownHero() {
        #expect(throws: ProfileValidationError.unknownHeroClass("nope")) {
            try ProfileRules.validated(profile(hero: "nope"), on: today, heroClasses: heroes)
        }
    }
}
