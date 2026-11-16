import Domain
import Foundation

/// The quest sheet's content: what to do, how to do it well (the tip) and the health line for medical tips.
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
            confirmTitle: strings.text(el: "Το έκανα!", en: "I did it!")
        )
    }
}
