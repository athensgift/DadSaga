import Application
import Domain
import Foundation

/// Home's title line: the level, which is the held title's order, then the title's name (ADR-0059 §1). No total, no
/// bar and no next title.
public struct TitleLineModel: Equatable, Sendable {
    /// e.g. "Επίπεδο 4 · Σίγουρα χέρια".
    public let text: String
    /// e.g. "Επίπεδο 4, Σίγουρα χέρια": VoiceOver hears a comma, not the dot.
    public let spoken: String
}

/// The dad's four skills under the title line, always in the same order (ADR-0059 §2). No number, no XP and no word
/// for how far one has grown.
public struct SkillMarksModel: Equatable, Sendable {
    /// "Οι δεξιότητές σου", what VoiceOver calls the row.
    public let label: String
    /// The four names as a list, e.g. "Φροντίδα, Παιχνίδι, Υπομονή και Αντοχή".
    public let value: String
    public let marks: [SkillMarkModel]
}

/// One skill's mark: its symbol from the cards, its name, and how much it has grown.
public struct SkillMarkModel: Equatable, Identifiable, Sendable {
    /// The skill's raw value, e.g. "patience": also the key of `HomeViewModel.skillBounces`.
    public let id: String
    /// e.g. "Υπομονή".
    public let name: String
    /// SF Symbol, as on the skill's cards.
    public let symbol: String
    /// From 0 up to, never reaching, 1 (`SkillGrowth`).
    public let growth: Double
}

extension HomeViewModel {
    /// "Επίπεδο 4" for the title's order, counted from 0.
    func level(of title: DadTitle) -> String {
        strings.text("Level \(title.order)")
    }

    func makeTitleLine(_ standing: DadStanding) -> TitleLineModel? {
        guard let title = standing.title else { return nil }
        let level = level(of: title)
        let name = title.name.resolved(for: locale)
        return TitleLineModel(text: "\(level) · \(name)", spoken: "\(level), \(name)")
    }

    func makeSkillMarks(_ skills: [SkillGrowth]) -> SkillMarksModel {
        let marks = skills.map { growth in
            SkillMarkModel(
                id: growth.skill.rawValue, name: strings.skill(growth.skill), symbol: growth.skill.symbol,
                growth: growth.value
            )
        }
        return SkillMarksModel(
            label: strings.text("Your skills"),
            value: marks.map(\.name).formatted(.list(type: .and).locale(locale)),
            marks: marks
        )
    }

    /// The celebrated card's skill, once its badge has gone: its mark bounces then, so the badge never hides it.
    func bounceSkill(grownBy celebrationID: Int) {
        guard let skill = celebratedSkills.removeValue(forKey: celebrationID) else { return }
        skillBounces[skill.rawValue, default: 0] += 1
    }
}
