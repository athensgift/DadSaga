import Application
import Domain
import Foundation
import Localization

/// The quest and boss sheets' content: what to do, how to do it well, and what the dad wrote last time.
extension HomeViewModel {
    /// - Parameter overview: what to read the child and the last note from.
    func detail(for quest: Quest, in overview: HomeOverview) -> QuestDetail {
        QuestDetail(
            id: quest.id,
            childID: overview.child.id,
            title: quest.title.resolved(for: locale),
            description: quest.description.resolved(for: locale),
            reward: strings.skill(quest.skill),
            tip: quest.tip.map { tip in
                TipDetail(title: tip.title.resolved(for: locale), steps: tip.steps.map { $0.resolved(for: locale) })
            },
            footer: quest.tip?.isMedical == true ? strings.medicalFooter : nil,
            confirmTitle: strings.text("I did it!"),
            journal: JournalLabels(locale: locale),
            lastJournal: lastJournal(for: .quest(id: quest.id), in: overview)
        )
    }

    func detail(for boss: BossFight, in overview: HomeOverview) -> BossDetail {
        BossDetail(
            id: boss.id,
            childID: overview.child.id,
            title: boss.title.resolved(for: locale),
            intro: boss.intro.resolved(for: locale),
            guideTitle: strings.text("Survival guide"),
            guide: boss.guide.map { $0.resolved(for: locale) },
            reward: boss.badge.resolved(for: locale),
            disclaimer: strings.medicalFooter,
            isDefeated: overview.defeatedBossIDs.contains(boss.id),
            recordedText: strings.recordedText(for: boss),
            confirmTitle: strings.text("We made it through!"),
            journal: JournalLabels(locale: locale),
            lastJournal: lastJournal(for: .boss(id: boss.id), in: overview)
        )
    }

    private func lastJournal(for kind: ProgressEvent.Kind, in overview: HomeOverview) -> LastJournal? {
        guard let entry = overview.progress.lastJournal(for: kind, childID: overview.child.id) else { return nil }
        let day = strings.day(entry.date)
        return LastJournal(
            title: entry.note == nil
                ? strings.text("Last time (\(day))")
                : strings.text("Last time (\(day)) you wrote:"),
            note: entry.note,
            photoIDs: entry.photoIDs
        )
    }
}
