import Application
import Domain
import Foundation
import Observation

/// Presenter for the home screen: the dad's hero, his companion, and what he can play today.
@MainActor
@Observable
public final class HomeViewModel {
    public private(set) var state: HomeViewState = .loading

    private let getProfile: any GetProfileUseCase
    private let loadCatalog: any LoadContentCatalogUseCase
    private let getAdventure: any GetAdventureUseCase
    private let locale: Locale
    private let now: @Sendable () -> Date

    public init(
        getProfile: any GetProfileUseCase,
        loadCatalog: any LoadContentCatalogUseCase,
        getAdventure: any GetAdventureUseCase,
        locale: Locale = .current,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.getProfile = getProfile
        self.loadCatalog = loadCatalog
        self.getAdventure = getAdventure
        self.locale = locale
        self.now = now
    }

    public func onAppear() async {
        do {
            guard let profile = try await getProfile.execute() else {
                state = .failed(message: text(el: "Δεν βρέθηκε προφίλ.", en: "No profile found."))
                return
            }
            let catalog = try await loadCatalog.execute()
            let adventure = try await getAdventure.execute(for: profile.child, on: now())
            state = .loaded(makeContent(profile: profile, catalog: catalog, adventure: adventure))
        } catch {
            state = .failed(message: text(el: "Το περιεχόμενο δεν φόρτωσε.", en: "Content failed to load."))
        }
    }

    private func makeContent(profile: PlayerProfile, catalog: ContentCatalog, adventure: Adventure) -> HomeContent {
        let hero = catalog.heroClasses.first { $0.id == profile.heroClassID }
        let progress = LevelCurve.progress(forTotalXP: 0)
        let worldID = adventure.currentWorld?.id
        return HomeContent(
            heroTitle: hero?.title.resolved(for: locale) ?? text(el: "Ήρωας", en: "Hero"),
            heroTagline: hero?.tagline.resolved(for: locale) ?? "",
            heroLook: HeroLook(heroClassID: profile.heroClassID),
            companionLine: "\(profile.child.name) · \(ageText(months: adventure.ageInMonths))",
            level: progress.level,
            levelFraction: progress.fraction,
            worldTitle: adventure.currentWorld?.title.resolved(for: locale),
            worldTagline: adventure.currentWorld?.tagline.resolved(for: locale),
            cards: bossCards(adventure.availableBosses.filter { $0.worldID == worldID })
                + questCards(adventure.availableQuests.filter { $0.worldID == worldID })
        )
    }

    private func bossCards(_ bosses: [BossFight]) -> [CardModel] {
        bosses.map { boss in
            CardModel(
                id: boss.id,
                title: boss.title.resolved(for: locale),
                subtitle: boss.intro.resolved(for: locale),
                badge: "BOSS",
                kind: .boss
            )
        }
    }

    private func questCards(_ quests: [Quest]) -> [CardModel] {
        quests.map { quest in
            CardModel(
                id: quest.id,
                title: quest.title.resolved(for: locale),
                subtitle: quest.description.resolved(for: locale),
                badge: "+\(quest.xp) XP · \(quest.skill.title.resolved(for: locale))",
                kind: .quest
            )
        }
    }

    private func ageText(months: Int) -> String {
        switch months {
        case 0: text(el: "νεογέννητο", en: "newborn")
        case 1: text(el: "1 μηνός", en: "1 month old")
        default: text(el: "\(months) μηνών", en: "\(months) months old")
        }
    }

    private func text(el: String, en: String) -> String {
        LocalizedText(el: el, en: en).resolved(for: locale)
    }
}
