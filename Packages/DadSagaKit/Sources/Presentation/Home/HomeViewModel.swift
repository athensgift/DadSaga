import Application
import Domain
import Foundation
import Localization
import Observation

/// Presenter for the home screen: the dad's hero, his children, and what he can play today with the chosen child.
@MainActor
@Observable
public final class HomeViewModel {
    public private(set) var state: HomeViewState = .loading
    public internal(set) var selectedQuest: QuestDetail? {
        didSet { selectionChanges += 1 }
    }
    public private(set) var selectedBoss: BossDetail? {
        didSet { selectionChanges += 1 }
    }
    public internal(set) var celebration: Celebration?
    /// "Undo" for a few seconds after the dad records something, in case he tapped by mistake.
    public internal(set) var undoOffer: UndoOffer?
    public internal(set) var errorMessage: String?
    /// The sheet for capturing a legendary moment, while it is open.
    public internal(set) var momentCapture: MomentCapture?
    /// A moment just recorded celebrates on home once its sheet has closed, not behind it (`sheetDismissed`).
    var pendingMomentCelebration: Celebration?
    public internal(set) var isCompleting = false
    /// The child whose world and quests are shown. The first child until the dad picks another.
    public internal(set) var selectedChildID: UUID?
    /// The world map, while it is open.
    public internal(set) var worldMap: WorldMapContent?
    /// The offer of a saga film, until the dad answers it (ADR-0037 §5).
    public internal(set) var sagaOffer: SagaFilmOffer?
    /// The film offers the dad answered in this session.
    var answeredSagaOffers: Set<String> = []
    /// The offer of a weekly reminder, until the dad answers it. It waits while a film is offered: home shows one
    /// offer at a time.
    public internal(set) var reminderOffer: ReminderOffer?
    /// The dad answered the reminder offer in this session.
    var reminderAnswered = false
    /// An earlier world the dad chose on the map, instead of the child's current one.
    var viewedWorldID: String?

    let useCases: UseCases
    let locale: Locale
    let strings: HomeStrings
    let momentsFormatter: MomentsFormatter
    let now: @Sendable () -> Date
    /// What the screen was last built from, for actions that need it (e.g. which firsts are left).
    private(set) var overview: HomeOverview?
    /// Counts each time a quest or boss sheet opens or closes, so a save that finishes later closes only the sheet it
    /// was started from, not one a widget link opened meanwhile.
    private var selectionChanges = 0
    private var celebrationCount = 0
    /// Each load takes a number; only the latest one may update the screen, so an older load that finishes last
    /// (e.g. home appearing while a widget link opens another child) cannot put back what it read.
    private var loadGeneration = 0

    public init(
        useCases: UseCases,
        locale: Locale = .current,
        timeZone: TimeZone = .autoupdatingCurrent,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.useCases = useCases
        self.locale = locale
        strings = HomeStrings(locale: locale)
        momentsFormatter = MomentsFormatter(strings: strings, locale: locale, timeZone: timeZone)
        self.now = now
    }

    public func onAppear() async {
        await load()
    }

    /// Reloads everything, e.g. after the family was edited.
    public func reload() async {
        await load()
    }

    /// Back in the app, perhaps a day later: the child's age, world and suggestions are read again.
    public func appBecameActive() async {
        guard state != .loading else { return }
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
        guard let overview else { return }
        if let quest = overview.quests.first(where: { $0.id == cardID }) {
            selectedQuest = detail(for: quest)
        } else if let boss = overview.bosses.first(where: { $0.id == cardID }) {
            selectedBoss = detail(for: boss)
        }
    }

    public func dismissSelection() {
        selectedQuest = nil
        selectedBoss = nil
        momentCapture = nil
        errorMessage = nil
    }

    /// Records the open quest, with the dad's optional note and photos.
    public func completeSelectedQuest(note: String = "", photos: PhotoDrafts = PhotoDrafts()) async {
        guard let quest = selectedQuest, let childID = selectedChildID else { return }
        let journal = JournalInput(note: note, photos: photos.pickedPhotos)
        let selection = selectionChanges
        guard let change = await record({
            try await self.useCases.completeQuest.execute(questID: quest.id, childID: childID, on: self.now(), journal: journal)
        }) else { return }
        if selection == selectionChanges { selectedQuest = nil }
        celebrate(change)
    }

    /// Records the open boss as defeated, with the dad's optional note and photos.
    public func defeatSelectedBoss(note: String = "", photos: PhotoDrafts = PhotoDrafts()) async {
        guard let boss = selectedBoss, !boss.isDefeated, let childID = selectedChildID else { return }
        let badge = overview?.bosses.first { $0.id == boss.id }?.badge.resolved(for: locale)
        let journal = JournalInput(note: note, photos: photos.pickedPhotos)
        let selection = selectionChanges
        guard let change = await record({
            try await self.useCases.defeatBoss.execute(bossID: boss.id, childID: childID, on: self.now(), journal: journal)
        }) else { return }
        if selection == selectionChanges { selectedBoss = nil }
        celebrate(change, badge: badge)
    }

    /// A celebration's time is up. Ignored if a newer one has replaced it.
    public func celebrationFinished(id: Int) {
        if celebration?.id == id { celebration = nil }
    }

    /// Runs a progress action and refreshes the screen. Returns what it changed, or `nil` after showing an error.
    /// It closes nothing: each caller decides what the dad sees next. The error belongs to the sheet the save was
    /// started from: if a widget link opened another sheet meanwhile, that one is not told of a save it never made.
    func record(_ action: () async throws -> ProgressChange) async -> ProgressChange? {
        guard !isCompleting else { return nil }
        isCompleting = true
        defer { isCompleting = false }
        let selection = selectionChanges
        do {
            let change = try await action()
            errorMessage = nil
            await load()
            return change
        } catch {
            if selection == selectionChanges { errorMessage = saveFailedMessage }
            return nil
        }
    }

    /// Home's celebration and "Saved · Undo" for a quest or boss.
    private func celebrate(_ change: ProgressChange, badge: String? = nil) {
        // A moment's celebration still waiting would only replace this newer one when the sheet closes.
        pendingMomentCelebration = nil
        let celebration = makeCelebration(change, badge: badge)
        self.celebration = celebration
        undoOffer = change.eventID.map { makeUndoOffer(id: celebration.id, eventID: $0) }
    }

    /// What a change gained, as a celebration with a new id.
    func makeCelebration(_ change: ProgressChange, badge: String? = nil, moment: String? = nil) -> Celebration {
        celebrationCount += 1
        return Celebration(
            id: celebrationCount,
            xpText: "+\(change.gainedXP) XP",
            levelUpText: change.leveledUp
                ? strings.text("Level \(change.after.level.level)") + "!"
                : nil,
            badgeText: badge,
            unlockText: change.newGear.first.map { strings.text("New: \($0.title.resolved(for: locale))") },
            momentText: moment
        )
    }

    var saveFailedMessage: String {
        strings.text("Couldn't save. Please try again.")
    }

    private func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        do {
            guard let overview = try await useCases.getOverview.execute(
                childID: selectedChildID, worldID: viewedWorldID, on: now()
            ) else {
                guard generation == loadGeneration else { return }
                state = .failed(message: strings.text("No profile found."))
                return
            }
            let sagaOffer = makeSagaOffer(overview)
            let reminderOffer = sagaOffer == nil
                ? await makeReminderOffer(children: overview.profile.children, progress: overview.progress)
                : nil
            guard generation == loadGeneration else { return }
            self.sagaOffer = sagaOffer
            self.reminderOffer = reminderOffer
            selectedChildID = overview.child.id
            viewedWorldID = overview.isShowingCurrentWorld ? nil : overview.shownWorld?.id
            self.overview = overview
            state = .loaded(makeContent(overview))
        } catch {
            guard generation == loadGeneration else { return }
            // A home that loaded once stays as it was: what it shows is still the dad's saga, only not refreshed.
            if case .loaded = state { return }
            state = .failed(message: strings.text("Content failed to load."))
        }
    }

    private func makeContent(_ overview: HomeOverview) -> HomeContent {
        let profile = overview.profile
        let child = overview.child
        let catalog = overview.catalog
        let adventure = overview.adventure
        let progress = overview.progress
        let level = progress.level
        let hero = catalog.hero(for: profile)
        let childLine = "\(child.name) · \(strings.ageText(months: adventure.ageInMonths))"
        let hasSiblings = profile.children.count > 1
        return HomeContent(
            heroTitle: hero?.title.resolved(for: locale) ?? strings.text("Hero"),
            heroTagline: hero?.tagline.resolved(for: locale) ?? "",
            heroLook: HeroLook(look: hero?.look),
            heroSkin: SkinToneChoice(profile.dadSkinTone),
            heroAppearance: DadAppearanceChoice(profile.dadAppearance),
            heroGear: overview.equippedGear.compactMap { HeroGearLook(look: $0.look) },
            medalCount: progress.allDefeatedBossIDs.count,
            companionLine: hasSiblings ? profile.children.map(\.name).joined(separator: " · ") : childLine,
            childTabs: hasSiblings ? profile.children.map { ChildTab(id: $0.id, name: $0.name) } : [],
            companions: profile.children.map { child in
                CompanionModel(
                    id: child.id,
                    name: child.name,
                    stage: CompanionStage(ageInMonths: child.ageInMonths(on: overview.today)),
                    gender: GenderChoice(child.gender),
                    skin: SkinToneChoice(child.skinTone),
                    traits: momentsFormatter.traits(for: child, catalog: catalog, progress: progress)
                )
            },
            selectedChildID: child.id,
            selectedChildLine: hasSiblings ? childLine : nil,
            familyTitle: strings.text("My family"),
            settingsTitle: strings.text("Settings"),
            level: level.level,
            levelTitle: strings.text("Level \(level.level)"),
            levelFraction: level.fraction,
            xpLine: "\(level.xpIntoLevel) / \(level.xpNeededForNextLevel) XP",
            worldTitle: overview.shownWorld?.title.resolved(for: locale),
            worldTagline: overview.shownWorld?.tagline.resolved(for: locale),
            mapTitle: strings.text("World map"),
            backToCurrentTitle: overview.isShowingCurrentWorld
                ? nil
                : strings.text("Back to the current world"),
            emptyMessage: adventure.isBeyondContent
                ? strings.text("Adventures for your child's age are coming soon.")
                : nil,
            cards: bossCards(overview) + questCards(overview),
            moments: momentsFormatter.section(for: child, catalog: catalog, progress: progress)
        )
    }

    private func bossCards(_ overview: HomeOverview) -> [CardModel] {
        let defeatedBossIDs = overview.defeatedBossIDs
        return overview.bosses.map { boss in
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

    private func questCards(_ overview: HomeOverview) -> [CardModel] {
        let completions = overview.progress.questCompletions(for: overview.child.id)
        return overview.quests.map { quest in
            CardModel(
                id: quest.id,
                title: quest.title.resolved(for: locale),
                subtitle: quest.description.resolved(for: locale),
                badge: "+\(quest.xp) XP",
                symbol: quest.skill.symbol,
                kind: .quest,
                footnote: completions[quest.id].map(strings.doneText),
                hint: quest.tip?.title.resolved(for: locale),
                skill: strings.skill(quest.skill)
            )
        }
    }
}
