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
    /// The skill's raw value, e.g. "patience".
    public let id: String
    /// e.g. "Υπομονή".
    public let name: String
    /// SF Symbol, as on the skill's cards.
    public let symbol: String
    /// From 0 up to, never reaching, 1 (`SkillGrowth`): how far the mark is drawn grown. After a card it stays where
    /// it was until the card's celebration has gone.
    public let growth: Double
    /// How many times the mark has risen after a card's celebration. A growth that changes with it rises gently; any
    /// other change, such as an undo's or a deletion's, is drawn at once.
    public let rises: Int
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

    /// The marks as home draws them now: each skill as far as the entries take it, except one whose card is still
    /// being celebrated, which waits where it was before that card.
    func makeSkillMarks(_ skills: [SkillGrowth]) -> SkillMarksModel {
        let marks = skills.map { growth in
            SkillMarkModel(
                id: growth.skill.rawValue, name: strings.skill(growth.skill), symbol: growth.skill.symbol,
                // Never above what the entries give: a deletion meanwhile still lowers it at once.
                growth: min(waitingSkillGrowth[growth.skill]?.first ?? growth.value, growth.value),
                rises: skillRises[growth.skill] ?? 0
            )
        }
        return SkillMarksModel(
            label: strings.text("Your skills"),
            value: marks.map(\.name).formatted(.list(type: .and).locale(locale)),
            marks: marks
        )
    }

    /// A card of this skill was just recorded: its mark waits where it was before the card until the card's
    /// celebration has gone, so the badge never hides the colour rising (ADR-0059 §2). Called before home is read
    /// again, so the mark is never drawn grown first.
    func holdMark(of skill: Skill?, before change: ProgressChange) {
        guard let skill, change.eventID != nil, let catalog = overview?.catalog,
              let before = SkillGrowth.all(change.before, catalog: catalog).first(where: { $0.skill == skill })
        else { return }
        waitingSkillGrowth[skill, default: []].append(before.value)
    }

    /// The celebrated card's skill, once its badge has gone, by its time or by a newer celebration: its mark rises
    /// now to where the card took it.
    func raiseMark(grownBy celebrationID: Int) {
        guard let skill = celebratedSkills.removeValue(forKey: celebrationID) else { return }
        if waitingSkillGrowth[skill]?.isEmpty == false { waitingSkillGrowth[skill]?.removeFirst() }
        skillRises[skill, default: 0] += 1
        showSkillMarks()
    }

    /// The card's celebration was taken away before its time, as an undo does: its mark no longer waits for it, and
    /// nothing rises. The marks are drawn again by whoever took it away, once the entry has gone or has stayed.
    func releaseMark(heldFor celebrationID: Int) {
        guard let skill = celebratedSkills.removeValue(forKey: celebrationID) else { return }
        if waitingSkillGrowth[skill]?.isEmpty == false { waitingSkillGrowth[skill]?.removeLast() }
    }

    /// Draws the marks again from what home last read, without reading it again.
    func showSkillMarks() {
        guard let overview, case .loaded(var content) = state else { return }
        content.skills = makeSkillMarks(overview.skills)
        state = .loaded(content)
    }
}
