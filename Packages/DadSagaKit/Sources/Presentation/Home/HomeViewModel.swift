import Application
import Domain
import Foundation
import Observation

/// Presenter for the home screen: the dad's hero, his children, and what he can play today with the chosen child.
@MainActor
@Observable
public final class HomeViewModel {
    public private(set) var state: HomeViewState = .loading
    public private(set) var selectedQuest: QuestDetail?
    public private(set) var selectedBoss: BossDetail?
    public private(set) var celebration: Celebration?
    /// "Undo" for a few seconds after the dad records something, in case he tapped by mistake.
    public internal(set) var undoOffer: UndoOffer?
    public internal(set) var errorMessage: String?
    /// The sheet for capturing a legendary moment, while it is open.
    public internal(set) var momentCapture: MomentCapture?
    public internal(set) var isCompleting = false
    /// The child whose world and quests are shown. The first child until the dad picks another.
    public private(set) var selectedChildID: UUID?
    /// The world map, while it is open.
    public internal(set) var worldMap: WorldMapContent?
    /// An earlier world the dad chose on the map, instead of the child's current one.
    var viewedWorldID: String?

    let useCases: UseCases
    let locale: Locale
    let strings: HomeStrings
    let momentsFormatter: MomentsFormatter
    let now: @Sendable () -> Date
    /// What the screen was last built from, for actions that need it (e.g. which firsts are left).
    private(set) var snapshot: HomeSnapshot?
    private var quests: [Quest] = []
    private var bosses: [BossFight] = []
    private(set) var defeatedBossIDs: Set<String> = []
    private var gear: [GearItem] = []
    private var outfit = Outfit()
    private var celebrationCount = 0

    public init(useCases: UseCases, locale: Locale = .current, now: @escaping @Sendable () -> Date = { .now }) {
        self.useCases = useCases
        self.locale = locale
        strings = HomeStrings(locale: locale)
        momentsFormatter = MomentsFormatter(strings: strings, locale: locale)
        self.now = now
    }

    public func onAppear() async {
        await load()
    }

    /// Reloads everything, e.g. after the family was edited.
    public func reload() async {
        await load()
    }

    public func selectChild(id: UUID) async {
        guard id != selectedChildID else { return }
        selectedChildID = id
        viewedWorldID = nil
        await load()
    }

    /// Opens the sheet for a quest ("did you do it?") or a boss (survival guide).
    public func select(cardID: String) {
        errorMessage = nil
        if let quest = quests.first(where: { $0.id == cardID }) {
            selectedQuest = detail(for: quest)
        } else if let boss = bosses.first(where: { $0.id == cardID }) {
            selectedBoss = detail(for: boss)
        }
    }

    public func dismissSelection() {
        selectedQuest = nil
        selectedBoss = nil
        momentCapture = nil
        errorMessage = nil
    }

    /// Records the open quest, with the dad's optional note and photo.
    public func completeSelectedQuest(note: String = "", photo: MomentPhotoEdit = .keep) async {
        guard let quest = selectedQuest, let childID = selectedChildID else { return }
        let journal = JournalInput(note: note, photo: photo.newData)
        await record(badge: nil) {
            try await self.useCases.completeQuest.execute(questID: quest.id, childID: childID, on: self.now(), journal: journal)
        }
    }

    /// Records the open boss as defeated, with the dad's optional note and photo.
    public func defeatSelectedBoss(note: String = "", photo: MomentPhotoEdit = .keep) async {
        guard let boss = selectedBoss, !boss.isDefeated, let childID = selectedChildID else { return }
        let badge = bosses.first { $0.id == boss.id }?.badge.resolved(for: locale)
        let journal = JournalInput(note: note, photo: photo.newData)
        await record(badge: badge) {
            try await self.useCases.defeatBoss.execute(bossID: boss.id, childID: childID, on: self.now(), journal: journal)
        }
    }

    public func celebrationFinished() {
        celebration = nil
    }

    /// Runs a progress action, then refreshes the screen and celebrates what it gained.
    func record(badge: String?, moment: String? = nil, _ action: () async throws -> ProgressChange) async {
        guard !isCompleting else { return }
        isCompleting = true
        defer { isCompleting = false }
        do {
            let change = try await action()
            selectedQuest = nil
            selectedBoss = nil
            momentCapture = nil
            await load()
            celebrationCount += 1
            celebration = Celebration(
                id: celebrationCount,
                xpText: "+\(change.gainedXP) XP",
                levelUpText: change.leveledUp
                    ? strings.text(el: "Επίπεδο \(change.after.level.level)!", en: "Level \(change.after.level.level)!")
                    : nil,
                badgeText: badge,
                unlockText: GearRules
                    .newlyEarned(gear, before: change.before.skillXP, after: change.after.skillXP)
                    .first
                    .map { strings.text(el: "Νέο: ", en: "New: ") + $0.title.resolved(for: locale) },
                momentText: moment
            )
            undoOffer = change.eventID.map { makeUndoOffer(id: celebrationCount, eventID: $0) }
        } catch {
            errorMessage = saveFailedMessage
        }
    }

    var saveFailedMessage: String {
        strings.text(el: "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.", en: "Couldn't save. Please try again.")
    }

    private func load() async {
        do {
            guard let profile = try await useCases.getProfile.execute(), let firstChild = profile.children.first else {
                state = .failed(message: strings.text(el: "Δεν βρέθηκε προφίλ.", en: "No profile found."))
                return
            }
            let child = profile.children.first { $0.id == selectedChildID } ?? firstChild
            selectedChildID = child.id
            let catalog = try await useCases.loadCatalog.execute()
            let adventure = try await useCases.getAdventure.execute(
                for: child,
                childCount: profile.children.count,
                on: now()
            )
            let progress = try await useCases.getProgress.execute()
            outfit = try await useCases.getOutfit?.execute() ?? Outfit()
            let world = adventure.unlockedWorlds.first { $0.id == viewedWorldID } ?? adventure.currentWorld
            if world?.id == adventure.currentWorld?.id { viewedWorldID = nil }
            let worldID = world?.id
            quests = world.map { UnlockRules.quests(for: $0, in: catalog, ageInMonths: adventure.ageInMonths) } ?? []
            bosses = adventure.availableBosses.filter { $0.worldID == worldID }
            defeatedBossIDs = progress.defeatedBossIDs(for: child.id)
            gear = catalog.gear
            snapshot = HomeSnapshot(
                child: child,
                catalog: catalog,
                progress: progress,
                adventure: adventure,
                childCount: profile.children.count
            )
            state = .loaded(
                makeContent(
                    profile: profile,
                    child: child,
                    catalog: catalog,
                    adventure: adventure,
                    progress: progress
                )
            )
        } catch {
            state = .failed(message: strings.text(el: "Το περιεχόμενο δεν φόρτωσε.", en: "Content failed to load."))
        }
    }

    private func makeContent(
        profile: PlayerProfile,
        child: Child,
        catalog: ContentCatalog,
        adventure: Adventure,
        progress: DadProgress
    ) -> HomeContent {
        let level = progress.level
        let hero = catalog.heroClasses.first { $0.id == profile.heroClassID }
        let childLine = "\(child.name) · \(strings.ageText(months: adventure.ageInMonths))"
        let hasSiblings = profile.children.count > 1
        return HomeContent(
            heroTitle: hero?.title.resolved(for: locale) ?? strings.text(el: "Ήρωας", en: "Hero"),
            heroTagline: hero?.tagline.resolved(for: locale) ?? "",
            heroLook: HeroLook(heroClassID: profile.heroClassID),
            heroSkin: SkinToneChoice(profile.dadSkinTone),
            heroGear: GearRules
                .equipped(catalog.gear, skillXP: progress.skillXP, outfit: outfit)
                .compactMap { HeroGearLook(look: $0.look) },
            medalCount: progress.allDefeatedBossIDs.count,
            companionLine: hasSiblings ? profile.children.map(\.name).joined(separator: " · ") : childLine,
            childTabs: hasSiblings ? profile.children.map { ChildTab(id: $0.id, name: $0.name) } : [],
            companions: profile.children.map { child in
                CompanionModel(
                    id: child.id,
                    name: child.name,
                    stage: CompanionStage(ageInMonths: child.ageInMonths(at: now())),
                    gender: GenderChoice(child.gender),
                    skin: SkinToneChoice(child.skinTone),
                    traits: momentsFormatter.traits(for: child, catalog: catalog, progress: progress)
                )
            },
            selectedChildID: child.id,
            selectedChildLine: hasSiblings ? childLine : nil,
            familyTitle: strings.text(el: "Η οικογένειά μου", en: "My family"),
            wardrobeTitle: strings.text(el: "Ντουλάπα", en: "Wardrobe"),
            level: level.level,
            levelTitle: strings.text(el: "Επίπεδο \(level.level)", en: "Level \(level.level)"),
            levelFraction: level.fraction,
            xpLine: "\(level.xpIntoLevel) / \(level.xpNeededForNextLevel) XP",
            worldTitle: shownWorld(adventure)?.title.resolved(for: locale),
            worldTagline: shownWorld(adventure)?.tagline.resolved(for: locale),
            mapTitle: strings.text(el: "Χάρτης κόσμων", en: "World map"),
            backToCurrentTitle: viewedWorldID == nil
                ? nil
                : strings.text(el: "Πίσω στον κόσμο του τώρα", en: "Back to the current world"),
            emptyMessage: adventure.isBeyondContent
                ? strings.text(
                    el: "Οι περιπέτειες για την ηλικία του παιδιού σου έρχονται σύντομα.",
                    en: "Adventures for your child's age are coming soon."
                )
                : nil,
            cards: bossCards() + questCards(completions: progress.questCompletions(for: child.id)),
            moments: momentsFormatter.section(for: child, catalog: catalog, progress: progress)
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
                footnote: defeatedBossIDs.contains(boss.id) ? strings.defeatedText(for: boss) : nil
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
                footnote: completions[quest.id].map(strings.doneText),
                hint: quest.tip?.title.resolved(for: locale),
                skill: quest.skill.title.resolved(for: locale)
            )
        }
    }
}
