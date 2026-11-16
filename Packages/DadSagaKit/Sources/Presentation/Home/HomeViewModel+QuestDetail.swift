import Domain
import Foundation

/// The quest and boss sheets' content: what to do, how to do it well, and what the dad wrote last time.
extension HomeViewModel {
    func detail(for quest: Quest) -> QuestDetail {
        QuestDetail(
            id: quest.id,
            title: quest.title.resolved(for: locale),
            description: quest.description.resolved(for: locale),
            reward: strings.reward(for: quest),
            tip: quest.tip.map { tip in
                TipDetail(title: tip.title.resolved(for: locale), steps: tip.steps.map { $0.resolved(for: locale) })
            },
            footer: quest.tip?.isMedical == true ? strings.medicalFooter : nil,
            confirmTitle: strings.text(el: "Το έκανα!", en: "I did it!"),
            journal: JournalLabels(locale: locale),
            lastJournal: lastJournal(for: .quest(id: quest.id))
        )
    }

    func detail(for boss: BossFight) -> BossDetail {
        BossDetail(
            id: boss.id,
            title: boss.title.resolved(for: locale),
            intro: boss.intro.resolved(for: locale),
            guideTitle: strings.text(el: "Οδηγός επιβίωσης", en: "Survival guide"),
            guide: boss.guide.map { $0.resolved(for: locale) },
            reward: "+\(boss.xp) XP · \(boss.badge.resolved(for: locale))",
            disclaimer: strings.medicalFooter,
            isDefeated: defeatedBossIDs.contains(boss.id),
            defeatedText: strings.defeatedText(for: boss),
            confirmTitle: strings.text(el: "Τα καταφέραμε!", en: "We made it through!"),
            journal: JournalLabels(locale: locale),
            lastJournal: lastJournal(for: .boss(id: boss.id))
        )
    }

    private func lastJournal(for kind: ProgressEvent.Kind) -> LastJournal? {
        guard let entry = snapshot?.progress.lastJournal(for: kind, childID: selectedChildID) else { return nil }
        let day = entry.date.formatted(Date.FormatStyle(locale: locale).day().month(.abbreviated))
        return LastJournal(
            title: entry.note == nil
                ? strings.text(el: "Την προηγούμενη φορά (\(day))", en: "Last time (\(day))")
                : strings.text(el: "Την προηγούμενη φορά (\(day)) έγραψες:", en: "Last time (\(day)) you wrote:"),
            note: entry.note,
            photoID: entry.photoID
        )
    }
}
