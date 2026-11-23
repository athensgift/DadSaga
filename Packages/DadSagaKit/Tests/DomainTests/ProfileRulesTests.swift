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

    @Test("Given onboarding with five children, when validating, then tooManyChildren is thrown")
    func tooManyChildren() {
        let five = (0..<5).map { _ in child() }
        #expect(throws: ProfileValidationError.tooManyChildren) {
            try ProfileRules.validated(profile(five), on: today, heroClasses: heroes)
        }
    }

    @Test("Given a family of four, when an edit adds a fifth, then tooManyChildren is thrown")
    func addingPastFour() {
        let four = (0..<4).map { _ in child() }
        #expect(throws: ProfileValidationError.tooManyChildren) {
            try ProfileRules.validated(FamilyEdit(added: [child()]), for: four, on: today)
        }
    }

    @Test("Given a family of five (two parents added at once), when an edit adds none, then it passes")
    func theLimitIsOnAddingOnly() throws {
        let five = (0..<5).map { _ in child() }
        var renamed = five[0]
        renamed.name = "Ίρις"
        let rename = FamilyEdit(changed: [ChildEdit(child: renamed, fields: [.name])], hasPartner: false)
        #expect(try ProfileRules.validated(rename, for: five, on: today).applied(to: five).count == 5)
        let removeOne = FamilyEdit(removedIDs: [five[4].id])
        #expect(try ProfileRules.validated(removeOne, for: five, on: today).applied(to: five).count == 4)
    }

    @Test("Given a family of five, when an edit removes two and adds one, then it passes at four")
    func removingMakesRoom() throws {
        let five = (0..<5).map { _ in child() }
        let edit = FamilyEdit(added: [child("Νέα")], removedIDs: [five[0].id, five[1].id])
        #expect(try ProfileRules.validated(edit, for: five, on: today).applied(to: five).count == 4)
    }

    @Test("Given an edit that removes every child, when validating, then noChildren is thrown")
    func editLeavingNone() {
        let family = [child(), child()]
        #expect(throws: ProfileValidationError.noChildren) {
            try ProfileRules.validated(FamilyEdit(removedIDs: Set(family.map(\.id))), for: family, on: today)
        }
    }

    @Test("Given an added or a renamed child with a blank name, when validating the edit, then emptyChildName is thrown")
    func blankNameInAnEdit() {
        let family = [child()]
        var blank = family[0]
        blank.name = "  "
        #expect(throws: ProfileValidationError.emptyChildName) {
            try ProfileRules.validated(FamilyEdit(added: [child(" ")]), for: family, on: today)
        }
        #expect(throws: ProfileValidationError.emptyChildName) {
            try ProfileRules.validated(
                FamilyEdit(changed: [ChildEdit(child: blank, fields: [.name])]), for: family, on: today
            )
        }
    }

    @Test("Given a renamed child, when validating the edit, then the new name is trimmed")
    func trimsARename() throws {
        let family = [child()]
        var renamed = family[0]
        renamed.name = " Ίρις "
        let valid = try ProfileRules.validated(
            FamilyEdit(changed: [ChildEdit(child: renamed, fields: [.name])]), for: family, on: today
        )
        #expect(valid.applied(to: family).map(\.name) == ["Ίρις"])
    }

    @Test("Given a changed birth day after today, when validating, then it is refused; a stored one left alone is not")
    func onlyWhatTheEditSetsIsChecked() throws {
        // Stored in a time zone further east: a day after today here (ADR-0053).
        let family = [child(bornDaysAgo: -1)]
        var moved = family[0]
        moved.birthDay = today.adding(days: 2)
        #expect(throws: ProfileValidationError.birthDateInFuture) {
            try ProfileRules.validated(
                FamilyEdit(changed: [ChildEdit(child: moved, fields: [.birthDay])]), for: family, on: today
            )
        }
        var renamed = family[0]
        renamed.name = "Ίρις"
        let rename = FamilyEdit(changed: [ChildEdit(child: renamed, fields: [.name])])
        #expect(try ProfileRules.validated(rename, for: family, on: today) == rename)
    }

    @Test("Given a hero edit, when it names an unknown hero, then unknownHeroClass is thrown; naming none is never checked")
    func heroEdit() throws {
        #expect(throws: ProfileValidationError.unknownHeroClass("nope")) {
            try ProfileRules.validated(HeroEdit(heroClassID: "nope"), heroClasses: heroes)
        }
        #expect(try ProfileRules.validated(HeroEdit(beard: .full), heroClasses: []) == HeroEdit(beard: .full))
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

    @Test("Given three, four or five in the family, when bringing a removed child back, then only three has room")
    func roomToBringBack() throws {
        let family = { (count: Int) in (0..<count).map { Child(name: "Παιδί \($0)", birthDay: nil) } }

        try ProfileRules.checkRoomToBringBack(into: family(3))
        #expect(throws: ProfileValidationError.tooManyChildren) { try ProfileRules.checkRoomToBringBack(into: family(4)) }
        #expect(throws: ProfileValidationError.tooManyChildren) { try ProfileRules.checkRoomToBringBack(into: family(5)) }
    }

    @Test("Given a removed child, when the picker asks for them, then it gets the family's first child")
    func removedChildIsNeverPicked() {
        let lena = Child(name: "Λένα", birthDay: nil)
        let iris = Child(name: "Ίρις", birthDay: nil)
        let profile = PlayerProfile(children: [lena], heroClassID: "h1", removedChildren: [iris])

        #expect(profile.child(iris.id) == lena)
    }
}
