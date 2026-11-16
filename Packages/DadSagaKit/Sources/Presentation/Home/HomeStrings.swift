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

    /// e.g. "0–8 μηνών", "2–3½ ετών", "από 6 ετών". The end is the last month of the world.
    func ageRange(from min: Int, to max: Int?) -> String {
        guard let max else { return text(el: "από ", en: "from ") + years(min) + text(el: " ετών", en: " years") }
        if max <= 24 { return "\(min)–\(max)" + text(el: " μηνών", en: " months") }
        return years(min) + "–" + years(max + 1) + text(el: " ετών", en: " years")
    }

    func unlocksIn(months: Int) -> String {
        months == 1
            ? text(el: "Ξεκλειδώνει σε 1 μήνα", en: "Unlocks in 1 month")
            : text(el: "Ξεκλειδώνει σε \(months) μήνες", en: "Unlocks in \(months) months")
    }

    /// What was kept in a world, never what was left undone (ADR-0020), e.g. "7 quests · 1 boss".
    func worldProgress(quests: Int, bosses: Int) -> String {
        "\(quests) " + (quests == 1 ? text(el: "αποστολή", en: "quest") : text(el: "αποστολές", en: "quests"))
            + " · \(bosses) " + (bosses == 1 ? text(el: "αφεντικό", en: "boss") : text(el: "αφεντικά", en: "bosses"))
    }

    /// The one health line under medical tips and boss guides. Lives here, not in the JSON, so it cannot drift.
    var medicalFooter: String {
        text(
            el: "Γενικές πληροφορίες. Δεν αντικαθιστούν τον παιδίατρό σου.",
            en: "General information. It does not replace your paediatrician."
        )
    }

    /// Whole and half years, e.g. "2", "3½".
    private func years(_ months: Int) -> String {
        "\(months / 12)" + (months % 12 >= 6 ? "½" : "")
    }
}
