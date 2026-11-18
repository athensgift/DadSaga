import Domain
import Foundation
import Localization
import Testing

@Suite("Strings from the catalog")
struct StringsTests {
    let greek = Strings(locale: Locale(identifier: "el_GR"))
    let english = Strings(locale: Locale(identifier: "en_US"))

    @Test("Given Greek and English, when the same key is resolved in one process, then each comes back in its own language")
    func bothLanguages() {
        #expect(greek.skill(.care) == "Φροντίδα")
        #expect(english.skill(.care) == "Care")
    }

    @Test("Given a German locale, when resolving, then the text is English, the same as content")
    func otherLanguagesAreEnglish() {
        #expect(Strings(locale: Locale(identifier: "de_DE")).skill(.play) == "Play")
    }

    @Test("Given counts 1 and 3, when resolving a plural key, then each language uses its singular and plural")
    func plurals() {
        #expect(greek.text("Done \(1) times") == "Το έκανες 1 φορά")
        #expect(greek.text("Done \(3) times") == "Το έκανες 3 φορές")
        #expect(english.text("Done \(1) times") == "Done once")
        #expect(english.text("Done \(3) times") == "Done 3 times")
    }

    @Test("Given a quest's XP and skill, when formatting the reward, then it reads in each language")
    func reward() {
        #expect(greek.reward(xp: 15, skill: .care) == "+15 XP · Φροντίδα")
        #expect(english.reward(xp: 15, skill: .care) == "+15 XP · Care")
    }
}
