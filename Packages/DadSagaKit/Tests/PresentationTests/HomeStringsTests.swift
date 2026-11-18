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

    @Test("Given a locked world one and two months away, then it says month, then months")
    func unlocksIn() {
        #expect(greek.unlocksIn(months: 1) == "Ξεκλειδώνει σε 1 μήνα")
        #expect(greek.unlocksIn(months: 2) == "Ξεκλειδώνει σε 2 μήνες")
        #expect(english.unlocksIn(months: 1) == "Unlocks in 1 month")
        #expect(english.unlocksIn(months: 2) == "Unlocks in 2 months")
    }

    @Test("Given a world with 1 quest and 2 bosses kept, then each count takes its own form")
    func worldProgress() {
        #expect(greek.worldProgress(quests: 1, bosses: 2) == "1 αποστολή · 2 αφεντικά")
        #expect(english.worldProgress(quests: 1, bosses: 2) == "1 quest · 2 bosses")
        #expect(english.worldProgress(quests: 7, bosses: 1) == "7 quests · 1 boss")
    }

    @Test("Given children of 0, 1, 5 and 30 months, then the age reads correctly in both languages")
    func ages() {
        #expect([0, 1, 5, 30].map(greek.ageText) == ["νεογέννητο", "1 μηνός", "5 μηνών", "2 ετών"])
        #expect([0, 1, 5, 30].map(english.ageText) == ["newborn", "1 month old", "5 months old", "2 years old"])
    }

    @Test("Given world age ranges, then months, years and open-ended ranges read in both languages")
    func ageRanges() {
        #expect(greek.ageRange(from: 0, to: 8) == "0–8 μηνών")
        #expect(greek.ageRange(from: 25, to: 41) == "2–3½ ετών")
        #expect(greek.ageRange(from: 72, to: nil) == "από 6 ετών")
        #expect(english.ageRange(from: 72, to: nil) == "from 6 years")
    }

    @Test("Given a quest, then the reward names the skill in each language")
    func reward() {
        let quest = HeroStub.catalog.quests[0]
        #expect(greek.reward(for: quest) == "+\(quest.xp) XP · Φροντίδα")
        #expect(english.reward(for: quest) == "+\(quest.xp) XP · Care")
    }
}
