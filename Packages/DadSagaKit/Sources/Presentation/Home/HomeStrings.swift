import Domain
import Foundation

/// Text and formatting for the home screen, in the user's language.
struct HomeStrings {
    let locale: Locale

    func defeatedText(for boss: BossFight) -> String {
        text(el: "Νικήθηκε", en: "Defeated") + " · " + boss.badge.resolved(for: locale)
    }

    func reward(for quest: Quest) -> String {
        "+\(quest.xp) XP · \(quest.skill.title.resolved(for: locale))"
    }

    func doneText(times: Int) -> String {
        times == 1
            ? text(el: "Το έκανες 1 φορά", en: "Done once")
            : text(el: "Το έκανες \(times) φορές", en: "Done \(times) times")
    }

    /// Months up to two years, then years.
    func ageText(months: Int) -> String {
        switch months {
        case 0: text(el: "νεογέννητο", en: "newborn")
        case 1: text(el: "1 μηνός", en: "1 month old")
        case ..<24: text(el: "\(months) μηνών", en: "\(months) months old")
        default: text(el: "\(months / 12) ετών", en: "\(months / 12) years old")
        }
    }

    func text(el: String, en: String) -> String {
        LocalizedText(el: el, en: en).resolved(for: locale)
    }
}
