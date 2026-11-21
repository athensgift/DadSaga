import Domain
import Foundation
import Testing
@testable import Presentation

@Suite("Home text in both languages")
struct HomeStringsTests {
    let greek = HomeStrings(locale: Locale(identifier: "el_GR"))
    let english = HomeStrings(locale: Locale(identifier: "en_US"))

    @Test("Given a quest done once and three times, then the footnote is singular, then plural, in both languages")
    func doneTimes() {
        #expect(greek.doneText(times: 1) == "Το έκανες 1 φορά")
        #expect(greek.doneText(times: 3) == "Το έκανες 3 φορές")
        #expect(english.doneText(times: 1) == "Done once")
        #expect(english.doneText(times: 3) == "Done 3 times")
    }

    @Test("Given a locked world one and two months away, then it says month, then months; before the birth, after the birth")
    func unlocksIn() {
        let world = World(id: "w2", order: 2, title: HeroStub.text, tagline: HeroStub.text, span: .months(min: 9, max: 24))
        #expect(greek.unlocks(world, at: .months(8)) == "Ξεκλειδώνει σε 1 μήνα")
        #expect(greek.unlocks(world, at: .months(7)) == "Ξεκλειδώνει σε 2 μήνες")
        #expect(english.unlocks(world, at: .months(8)) == "Unlocks in 1 month")
        #expect(english.unlocks(world, at: .months(7)) == "Unlocks in 2 months")
        #expect(greek.unlocks(world, at: .beforeBirth) == "Ανοίγει μετά τη γέννα")
        #expect(english.unlocks(world, at: .beforeBirth) == "Opens after the birth")
    }

    @Test("Given a world with 1 quest and 2 bosses kept, then each count takes its own form")
    func worldProgress() {
        #expect(greek.worldProgress(quests: 1, bosses: 2) == "1 αποστολή · 2 αφεντικά")
        #expect(english.worldProgress(quests: 1, bosses: 2) == "1 quest · 2 bosses")
        #expect(english.worldProgress(quests: 7, bosses: 1) == "7 quests · 1 boss")
    }

    @Test("Given a child on the way and of 0, 1, 5 and 30 months, then the age reads correctly in both languages")
    func ages() {
        let ages: [ChildAge] = [.beforeBirth, .months(0), .months(1), .months(5), .months(30)]
        #expect(ages.map(greek.ageText) == ["έρχεται", "νεογέννητο", "1 μηνός", "5 μηνών", "2 ετών"])
        #expect(ages.map(english.ageText) == ["on the way", "newborn", "1 month old", "5 months old", "2 years old"])
    }

    @Test("Given world age ranges, then months, years and open-ended ranges read in both languages")
    func ageRanges() {
        #expect(greek.ageRange(.months(min: 0, max: 8)) == "0–8 μηνών")
        #expect(greek.ageRange(.months(min: 25, max: 41)) == "2–3½ ετών")
        #expect(greek.ageRange(.months(min: 72, max: nil)) == "από 6 ετών")
        #expect(english.ageRange(.months(min: 72, max: nil)) == "from 6 years")
        #expect(greek.ageRange(.beforeBirth) == "πριν τη γέννα")
        #expect(english.ageRange(.beforeBirth) == "before birth")
    }

    @Test("Given a quest, then the reward names the skill in each language")
    func reward() {
        let quest = HeroStub.catalog.quests[0]
        #expect(greek.reward(for: quest) == "+\(quest.xp) XP · Φροντίδα")
        #expect(english.reward(for: quest) == "+\(quest.xp) XP · Care")
    }
}
