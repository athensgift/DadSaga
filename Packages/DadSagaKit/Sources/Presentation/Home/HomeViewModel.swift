import Application
import Domain
import Foundation
import Observation

/// Presenter for the home screen: the dad's hero, his companion, and what he can play today.
@MainActor
@Observable
public final class HomeViewModel {
    public struct UseCases: Sendable {
        let getProfile: any GetProfileUseCase
        let loadCatalog: any LoadContentCatalogUseCase
        let getAdventure: any GetAdventureUseCase
        let getProgress: any GetProgressUseCase
        let completeQuest: any CompleteQuestUseCase
        let defeatBoss: any DefeatBossUseCase

        public init(
            getProfile: any GetProfileUseCase,
            loadCatalog: any LoadContentCatalogUseCase,
            getAdventure: any GetAdventureUseCase,
            getProgress: any GetProgressUseCase,
            completeQuest: any CompleteQuestUseCase,
            defeatBoss: any DefeatBossUseCase
        ) {
            self.getProfile = getProfile
            self.loadCatalog = loadCatalog
            self.getAdventure = getAdventure
            self.getProgress = getProgress
            self.completeQuest = completeQuest
            self.defeatBoss = defeatBoss
        }
    }

    public private(set) var state: HomeViewState = .loading
    public private(set) var selectedQuest: QuestDetail?
    public private(set) var selectedBoss: BossDetail?
    public private(set) var celebration: Celebration?
    public private(set) var errorMessage: String?
    public private(set) var isCompleting = false

    private let useCases: UseCases
    private let locale: Locale
    private let now: @Sendable () -> Date
    private var quests: [Quest] = []
    private var bosses: [BossFight] = []
    private var defeatedBossIDs: Set<String> = []
    private var celebrationCount = 0

    public init(useCases: UseCases, locale: Locale = .current, now: @escaping @Sendable () -> Date = { .now }) {
        self.useCases = useCases
        self.locale = locale
        self.now = now
    }

    public func onAppear() async {
        await load()
    }

    /// Opens the sheet for a quest ("did you do it?") or a boss (survival guide).
    public func select(cardID: String) {
        errorMessage = nil
        if let quest = quests.first(where: { $0.id == cardID }) {
            selectedQuest = QuestDetail(
                id: quest.id,
                title: quest.title.resolved(for: locale),
                description: quest.description.resolved(for: locale),
                reward: reward(for: quest),
                confirmTitle: text(el: "Το έκανα!", en: "I did it!")
            )
        } else if let boss = bosses.first(where: { $0.id == cardID }) {
            selectedBoss = detail(for: boss)
        }
    }

    public func dismissSelection() {
        selectedQuest = nil
        selectedBoss = nil
        errorMessage = nil
    }

    public func completeSelectedQuest() async {
        guard let quest = selectedQuest else { return }
        await record(badge: nil) {
            try await self.useCases.completeQuest.execute(questID: quest.id, on: self.now())
        }
    }

    public func defeatSelectedBoss() async {
        guard let boss = selectedBoss, !boss.isDefeated else { return }
        let badge = bosses.first { $0.id == boss.id }?.badge.resolved(for: locale)
        await record(badge: badge) {
            try await self.useCases.defeatBoss.execute(bossID: boss.id, on: self.now())
        }
    }

    public func celebrationFinished() {
        celebration = nil
    }

    /// Runs a progress action, then refreshes the screen and celebrates what it gained.
    private func record(badge: String?, _ action: () async throws -> ProgressChange) async {
        guard !isCompleting else { return }
        isCompleting = true
        defer { isCompleting = false }
        do {
            let change = try await action()
            selectedQuest = nil
            selectedBoss = nil
            await load()
            celebrationCount += 1
            celebration = Celebration(
                id: celebrationCount,
                xpText: "+\(change.gainedXP) XP",
                levelUpText: change.leveledUp
                    ? text(el: "Επίπεδο \(change.after.level.level)!", en: "Level \(change.after.level.level)!")
                    : nil,
                badgeText: badge
            )
        } catch {
            errorMessage = text(el: "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.", en: "Couldn't save. Please try again.")
        }
    }

    private func load() async {
        do {
            guard let profile = try await useCases.getProfile.execute() else {
                state = .failed(message: text(el: "Δεν βρέθηκε προφίλ.", en: "No profile found."))
                return
            }
            let catalog = try await useCases.loadCatalog.execute()
            let adventure = try await useCases.getAdventure.execute(for: profile.child, on: now())
            let progress = try await useCases.getProgress.execute()
            let worldID = adventure.currentWorld?.id
            quests = adventure.availableQuests.filter { $0.worldID == worldID }
            bosses = adventure.availableBosses.filter { $0.worldID == worldID }
            defeatedBossIDs = progress.defeatedBossIDs
            state = .loaded(makeContent(profile: profile, catalog: catalog, adventure: adventure, progress: progress))
        } catch {
            state = .failed(message: text(el: "Το περιεχόμενο δεν φόρτωσε.", en: "Content failed to load."))
        }
    }

    private func makeContent(
        profile: PlayerProfile,
        catalog: ContentCatalog,
        adventure: Adventure,
        progress: DadProgress
    ) -> HomeContent {
        let hero = catalog.heroClasses.first { $0.id == profile.heroClassID }
        let level = progress.level
        return HomeContent(
            heroTitle: hero?.title.resolved(for: locale) ?? text(el: "Ήρωας", en: "Hero"),
            heroTagline: hero?.tagline.resolved(for: locale) ?? "",
            heroLook: HeroLook(heroClassID: profile.heroClassID),
            companionLine: "\(profile.child.name) · \(ageText(months: adventure.ageInMonths))",
            level: level.level,
            levelTitle: text(el: "Επίπεδο \(level.level)", en: "Level \(level.level)"),
            levelFraction: level.fraction,
            xpLine: "\(level.xpIntoLevel) / \(level.xpNeededForNextLevel) XP",
            worldTitle: adventure.currentWorld?.title.resolved(for: locale),
            worldTagline: adventure.currentWorld?.tagline.resolved(for: locale),
            cards: bossCards() + questCards(completions: progress.questCompletions)
        )
    }

    private func bossCards() -> [CardModel] {
        bosses.map { boss in
            CardModel(
                id: boss.id,
                title: boss.title.resolved(for: locale),
                subtitle: boss.intro.resolved(for: locale),
                badge: "BOSS",
                symbol: "flame.fill",
                kind: .boss,
                footnote: defeatedBossIDs.contains(boss.id) ? defeatedText(for: boss) : nil
            )
        }
    }

    private func questCards(completions: [String: Int]) -> [CardModel] {
        quests.map { quest in
            CardModel(
                id: quest.id,
                title: quest.title.resolved(for: locale),
                subtitle: quest.description.resolved(for: locale),
                badge: "+\(quest.xp) XP",
                symbol: quest.skill.symbol,
                kind: .quest,
                footnote: completions[quest.id].map(doneText)
            )
        }
    }

    private func detail(for boss: BossFight) -> BossDetail {
        BossDetail(
            id: boss.id,
            title: boss.title.resolved(for: locale),
            intro: boss.intro.resolved(for: locale),
            guideTitle: text(el: "Οδηγός επιβίωσης", en: "Survival guide"),
            guide: boss.guide.map { $0.resolved(for: locale) },
            reward: "+\(boss.xp) XP · \(boss.badge.resolved(for: locale))",
            disclaimer: text(
                el: "Γενικές πληροφορίες, όχι ιατρική συμβουλή. Ρώτα πάντα τον παιδίατρό σου.",
                en: "General information, not medical advice. Always ask your paediatrician."
            ),
            isDefeated: defeatedBossIDs.contains(boss.id),
            defeatedText: defeatedText(for: boss),
            confirmTitle: text(el: "Τα καταφέραμε!", en: "We made it through!")
        )
    }

    private func defeatedText(for boss: BossFight) -> String {
        text(el: "Νικήθηκε", en: "Defeated") + " · " + boss.badge.resolved(for: locale)
    }

    private func reward(for quest: Quest) -> String {
        "+\(quest.xp) XP · \(quest.skill.title.resolved(for: locale))"
    }

    private func doneText(times: Int) -> String {
        times == 1
            ? text(el: "Το έκανες 1 φορά", en: "Done once")
            : text(el: "Το έκανες \(times) φορές", en: "Done \(times) times")
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
