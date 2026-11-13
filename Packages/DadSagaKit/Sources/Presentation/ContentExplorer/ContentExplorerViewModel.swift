import Application
import Domain
import Foundation
import Observation

/// Presenter for the content explorer. Calls the use case and maps Domain entities to display models.
/// Deliberately does not import SwiftUI, so it is unit-testable and UI-framework agnostic.
@MainActor
@Observable
public final class ContentExplorerViewModel {
    public private(set) var state: ContentExplorerViewState = .loading

    private let loadCatalog: any LoadContentCatalogUseCase
    private let locale: Locale

    public init(loadCatalog: any LoadContentCatalogUseCase, locale: Locale = .current) {
        self.loadCatalog = loadCatalog
        self.locale = locale
    }

    public func onAppear() async {
        state = .loading
        do {
            let catalog = try await loadCatalog.execute()
            state = .loaded(makeContent(from: catalog))
        } catch {
            state = .failed(message: text(el: "Το περιεχόμενο δεν φόρτωσε.", en: "Content failed to load."))
        }
    }

    private func makeContent(from catalog: ContentCatalog) -> ContentExplorerContent {
        let progress = LevelCurve.progress(forTotalXP: 0)
        let worlds = catalog.worlds.map { world in
            let bosses = catalog.bosses.filter { $0.worldID == world.id }.map { boss in
                CardModel(
                    id: boss.id,
                    title: boss.title.resolved(for: locale),
                    subtitle: boss.intro.resolved(for: locale),
                    badge: "BOSS",
                    kind: .boss
                )
            }
            let quests = catalog.quests.filter { $0.worldID == world.id }.map { quest in
                CardModel(
                    id: quest.id,
                    title: quest.title.resolved(for: locale),
                    subtitle: quest.description.resolved(for: locale),
                    badge: "+\(quest.xp) XP · \(quest.skill.title.resolved(for: locale))",
                    kind: .quest
                )
            }
            return WorldSection(
                id: world.id,
                title: world.title.resolved(for: locale),
                tagline: world.tagline.resolved(for: locale),
                cards: bosses + quests
            )
        }
        let firsts = catalog.firsts.map { first in
            CardModel(
                id: first.id,
                title: "\(first.emoji) \(first.title.resolved(for: locale))",
                subtitle: first.companionTrait.map { "Companion: \($0)" } ?? "",
                badge: "LEGENDARY",
                kind: .legendary
            )
        }
        return ContentExplorerContent(
            level: progress.level,
            levelFraction: progress.fraction,
            worlds: worlds,
            firstsTitle: text(el: "Θρυλικές στιγμές", en: "Legendary moments"),
            firsts: firsts
        )
    }

    private func text(el: String, en: String) -> String {
        LocalizedText(el: el, en: en).resolved(for: locale)
    }
}
