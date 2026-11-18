import Domain
import Foundation
import Localization

/// Text and formatting for the home screen, in the user's language (ADR-0027).
struct HomeStrings {
    let strings: Strings
    var locale: Locale { strings.locale }

    init(locale: Locale) {
        strings = Strings(locale: locale)
    }

    func text(_ key: String.LocalizationValue) -> String {
        strings.text(key)
    }

    func defeatedText(for boss: BossFight) -> String {
        strings.text("Defeated") + " · " + boss.badge.resolved(for: locale)
    }

    func skill(_ skill: Skill) -> String {
        strings.skill(skill)
    }

    func day(_ date: Date) -> String {
        strings.day(date)
    }

    func reward(for quest: Quest) -> String {
        strings.reward(xp: quest.xp, skill: quest.skill)
    }

    func doneText(times: Int) -> String {
        strings.text("Done \(times) times")
    }

    /// Months up to two years, then years.
    func ageText(months: Int) -> String {
        switch months {
        case 0: strings.text("newborn")
        case ..<24: strings.text("\(months) months old")
        default: strings.text("\(months / 12) years old")
        }
    }

    /// e.g. "0–8 μηνών", "2–3½ ετών", "από 6 ετών". The end is the last month of the world.
    func ageRange(from min: Int, to max: Int?) -> String {
        guard let max else { return strings.text("from \(years(min)) years") }
        if max <= 24 { return strings.text("\(min)–\(max) months") }
        return strings.text("\(years(min))–\(years(max + 1)) years")
    }

    func unlocksIn(months: Int) -> String {
        strings.text("Unlocks in \(months) months")
    }

    /// What was kept in a world, never what was left undone (ADR-0020), e.g. "7 quests · 1 boss".
    func worldProgress(quests: Int, bosses: Int) -> String {
        strings.text("\(quests) quests") + " · " + strings.text("\(bosses) bosses")
    }

    /// The one health line under medical tips and boss guides. Lives here, not in the JSON, so it cannot drift.
    var medicalFooter: String {
        strings.text("General information. It does not replace your paediatrician.")
    }

    /// Whole and half years, e.g. "2", "3½".
    private func years(_ months: Int) -> String {
        "\(months / 12)" + (months % 12 >= 6 ? "½" : "")
    }
}
