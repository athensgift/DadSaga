import Application
import Domain
import Foundation

/// The cards home shows for the selected child: the companions beside the hero, quests, bosses and the bosses for when
/// life changes.
extension HomeViewModel {
    /// Every child as drawn beside the dad today: the mark for a child on the way (ADR-0053 §2).
    func companions(_ overview: HomeOverview) -> [CompanionModel] {
        overview.profile.children.map { child in
            CompanionModel(
                child: child,
                on: overview.today,
                traits: momentsFormatter.traits(for: child, catalog: overview.catalog, progress: overview.progress),
                strings: strings.strings
            )
        }
    }

    /// "When life changes", after the cards; `nil` when the world has none. Its id changes only when home is opened or
    /// shows another child or world, so the row starts closed then and stays open through a save (ADR-0053 §5).
    func situationalCards(_ overview: HomeOverview) -> SituationalCards? {
        guard !overview.situationalBosses.isEmpty, let world = overview.shownWorld else { return nil }
        return SituationalCards(
            id: "\(overview.child.id.uuidString)/\(world.id)/\(situationalVisit)",
            title: strings.text("When life changes"),
            cards: bossCards(overview.situationalBosses, overview: overview)
        )
    }

    func bossCards(_ bosses: [BossFight], overview: HomeOverview) -> [CardModel] {
        let defeatedBossIDs = overview.defeatedBossIDs
        return bosses.map { boss in
            CardModel(
                id: boss.id,
                title: boss.title.resolved(for: locale),
                subtitle: boss.intro.resolved(for: locale),
                badge: strings.text("BOSS"),
                symbol: "flame.fill",
                kind: .boss,
                footnote: defeatedBossIDs.contains(boss.id) ? strings.defeatedText(for: boss) : nil
            )
        }
    }

    func questCards(_ overview: HomeOverview) -> [CardModel] {
        let completions = overview.progress.questCompletions(for: overview.child.id)
        return overview.quests.map { quest in
            CardModel(
                id: quest.id,
                title: quest.title.resolved(for: locale),
                subtitle: quest.description.resolved(for: locale),
                badge: nil,
                symbol: quest.skill.symbol,
                kind: .quest,
                footnote: completions[quest.id].map(strings.doneText),
                hint: quest.tip?.title.resolved(for: locale),
                skill: strings.skill(quest.skill)
            )
        }
    }
}
