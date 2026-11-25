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

    @Test("Given worlds from the birth, 1 and 9 months, 2 and 3½ years, then each says when it is ideal, never a countdown")
    func idealStart() {
        func world(_ span: WorldSpan) -> World {
            World(id: "w", order: 1, title: HeroStub.text, tagline: HeroStub.text, span: span)
        }
        #expect(greek.idealStart(world(.months(min: 0, max: 8))) == "Ιδανικά μετά τη γέννα")
        #expect(english.idealStart(world(.months(min: 0, max: 8))) == "Ideally after the birth")
        #expect(greek.idealStart(world(.months(min: 1, max: 8))) == "Ιδανικά από τον 1 μήνα")
        #expect(greek.idealStart(world(.months(min: 9, max: 24))) == "Ιδανικά από τους 9 μήνες")
        #expect(english.idealStart(world(.months(min: 1, max: 8))) == "Ideally from 1 month")
        #expect(english.idealStart(world(.months(min: 9, max: 24))) == "Ideally from 9 months")
        #expect(greek.idealStart(world(.months(min: 24, max: 41))) == "Ιδανικά από τα 2 χρόνια")
        #expect(english.idealStart(world(.months(min: 42, max: nil))) == "Ideally from 3½ years")
        #expect(greek.idealStart(world(.beforeBirth)) == nil)
    }

    @Test("Given a world with 1 quest and 2 bosses kept, then each count takes its own form")
    func worldProgress() {
        #expect(greek.worldProgress(quests: 1, bosses: 2) == "1 αποστολή · 2 bosses")
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

    @Test("Given a boss for when life changes, once recorded, then it reads as having been there, every other as defeated")
    func recordedBoss() {
        func boss(isSituational: Bool) -> BossFight {
            BossFight(
                id: "b", worldID: "w", title: HeroStub.text, intro: HeroStub.text, guide: [],
                badge: LocalizedText(el: "Σταθερό έδαφος", en: "Solid Ground"), skill: .resilience, xp: 100,
                minAgeMonths: 0, isSituational: isSituational
            )
        }
        #expect(greek.recordedText(for: boss(isSituational: true)) == "Ήσουν εκεί · Σταθερό έδαφος")
        #expect(english.recordedText(for: boss(isSituational: true)) == "You were there · Solid Ground")
        #expect(greek.recordedText(for: boss(isSituational: false)) == "Νικήθηκε · Σταθερό έδαφος")
        #expect(english.recordedText(for: boss(isSituational: false)) == "Defeated · Solid Ground")
    }
}
