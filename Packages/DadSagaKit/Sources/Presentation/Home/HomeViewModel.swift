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
    public internal(set) var selectedQuest: QuestDetail?
    public internal(set) var selectedBoss: BossDetail?
    public internal(set) var celebration: Celebration?
    /// "Undo" for a few seconds after the dad records something, in case he tapped by mistake.
    public internal(set) var undoOffer: UndoOffer?
    public internal(set) var errorMessage: String?
    /// The sheet for capturing a legendary moment, while it is open. Its Undo, once gone, can't be used again.
    public internal(set) var momentCapture: MomentCapture? {
        didSet {
            let offer = oldValue?.details?.undoOffer
            if let offer, offer.eventID != momentCapture?.details?.undoOffer?.eventID { forgetUndo(of: offer) }
        }
    }
    /// A moment just recorded celebrates on home once its sheet has closed, not behind it (`sheetDismissed`).
    var pendingMomentCelebration: Celebration?
    public internal(set) var isCompleting = false
    /// The child whose world and quests are shown. The first child until the dad picks another.
    public internal(set) var selectedChildID: UUID?
    /// The world map, while it is open.
    public internal(set) var worldMap: WorldMapContent?
    /// The offer of a saga film, until the dad answers it (ADR-0037 §5).
    public internal(set) var sagaOffer: SagaFilmOffer?
    /// The card for a new title: shown before any offer (ADR-0055 §6).
    public internal(set) var titleCard: TitleCard?
    /// Titles whose card was closed in this session, so a reload while the close is being saved can't bring it back.
    var closedTitleCards: Set<String> = []
    /// The film offers the dad answered in this session.
    var answeredSagaOffers: Set<String> = []
    /// The offer of a weekly reminder, until the dad answers it. It waits while a film is offered: home shows one
    /// offer at a time.
    public internal(set) var reminderOffer: ReminderOffer?
    /// The dad answered the reminder offer in this session.
    var reminderAnswered = false
    /// An earlier world the dad chose on the map, instead of the child's current one.
    var viewedWorldID: String?
    /// How many times each skill's mark has bounced, by the mark's id: once for each card of the skill, as its
    /// celebration goes (ADR-0059 §2).
    public internal(set) var skillBounces: [String: Int] = [:]
    /// The skill each celebration on screen grew, by its id, until it goes. Only home's view model knows it.
    @ObservationIgnored var celebratedSkills: [Int: Skill] = [:]
    /// The entries whose Undo is on screen, in the order they were recorded, with what the store kept before each.
    @ObservationIgnored var undoable: [UndoableEntry] = []

    let useCases: UseCases
    let locale: Locale
    let strings: HomeStrings
    let momentsFormatter: MomentsFormatter
    let now: @Sendable () -> Date
    /// What the screen was last built from, for actions that need it (e.g. which firsts are left).
    private(set) var overview: HomeOverview?
    @ObservationIgnored private var celebrationCount = 0
    /// The last celebration VoiceOver read.
    @ObservationIgnored private var announcedCelebrationID: Int?
    /// Each load takes a number; only the latest one may update the screen, so an older load that finishes last
    /// (e.g. home appearing while a widget link opens another child) cannot put back what it read.
    @ObservationIgnored private var loadGeneration = 0
    /// Loads under way: coming back to the app starts none while one is.
    @ObservationIgnored private var loadsUnderWay = 0
    /// Goes up when home is opened, another child is chosen or another world is shown: "When life changes" starts
    /// closed then, and stays as the dad left it through every other reload (ADR-0053 §5).
    @ObservationIgnored var situationalVisit = 0

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
        situationalVisit += 1
        await load()
    }

    /// Reloads everything, e.g. after the family was edited.
    public func reload() async {
        await load()
    }

    /// Back in the app, perhaps a day later: the child's age, world and suggestions are read again. Not while a load
    /// is under way: that one already reads what is true now.
    public func appBecameActive() async {
        guard state != .loading, loadsUnderWay == 0 else { return }
        await load()
    }

    public func selectChild(id: UUID) async {
        guard id != selectedChildID else { return }
        selectedChildID = id
        viewedWorldID = nil
        situationalVisit += 1
        await load()
    }

    /// Opens the sheet for a quest ("did you do it?") or a boss (survival guide).
    public func select(cardID: String) {
        errorMessage = nil
        guard let overview else { return }
        if let quest = overview.quests.first(where: { $0.id == cardID }) {
            selectedQuest = detail(for: quest)
        } else if let boss = (overview.bosses + overview.situationalBosses).first(where: { $0.id == cardID }) {
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
        guard let change = await record({
            try await self.useCases.completeQuest.execute(questID: quest.id, childID: childID, on: self.now(), journal: journal)
        }) else { return }
        selectedQuest = nil
        celebrate(change, skill: overview?.catalog.quest(id: quest.id)?.skill)
    }

    /// Records the open boss as defeated, with the dad's optional note and photos.
    public func defeatSelectedBoss(note: String = "", photos: PhotoDrafts = PhotoDrafts()) async {
        guard let boss = selectedBoss, !boss.isDefeated, let childID = selectedChildID else { return }
        let content = overview?.catalog.boss(id: boss.id)
        let badge = content?.badge.resolved(for: locale)
        let journal = JournalInput(note: note, photos: photos.pickedPhotos)
        guard let change = await record({
            try await self.useCases.defeatBoss.execute(bossID: boss.id, childID: childID, on: self.now(), journal: journal)
        }) else { return }
        selectedBoss = nil
        celebrate(change, skill: content?.skill, badge: badge)
    }

    /// A celebration's time is up, and the mark of the skill it grew bounces. Ignored if a newer one has replaced it.
    public func celebrationFinished(id: Int) {
        guard celebration?.id == id else { return }
        celebration = nil
        bounceSkill(grownBy: id)
    }

    /// Takes a celebration away before its time, as an undo does: nothing grew, so no mark bounces. Ignored if a newer
    /// one has replaced it.
    func withdrawCelebration(id: Int) {
        guard celebration?.id == id else { return }
        celebration = nil
        celebratedSkills[id] = nil
    }

    /// Puts a celebration on screen. One it replaces has gone as surely as one whose time is up, so its skill's mark
    /// bounces now: a second card within seconds still shows on the first one's mark.
    func show(_ celebration: Celebration) {
        if let replaced = self.celebration, replaced.id != celebration.id { bounceSkill(grownBy: replaced.id) }
        self.celebration = celebration
    }

    /// Whether VoiceOver should read this celebration now: only the first time. Its time on screen starts again when
    /// home comes back from the other tab, but it was already read.
    public func shouldAnnounce(_ celebration: Celebration) -> Bool {
        guard celebration.id != announcedCelebrationID else { return false }
        announcedCelebrationID = celebration.id
        return true
    }

    /// Runs a progress action and refreshes the screen. Returns what it changed, or `nil` after showing an error.
    /// It closes nothing: each caller decides what the dad sees next. A link from outside waits while it runs
    /// (`receive`), so the open sheet is still the one the save came from. The last error goes as the
    /// save starts, so the same error again is read out again.
    func record(_ action: () async throws -> ProgressChange) async -> ProgressChange? {
        guard !isCompleting else { return nil }
        isCompleting = true
        defer { isCompleting = false }
        errorMessage = nil
        do {
            let change = try await action()
            await load()
            return change
        } catch {
            errorMessage = saveFailedMessage
            return nil
        }
    }

    /// Home's celebration and "Saved · Undo" for a quest or boss.
    private func celebrate(_ change: ProgressChange, skill: Skill?, badge: String? = nil) {
        // A moment's celebration still waiting would only replace this newer one when the sheet closes.
        pendingMomentCelebration = nil
        let celebration = makeCelebration(skill: skill, badge: badge)
        show(celebration)
        // The bar shows one offer: the one it replaces can't be used again.
        if let replaced = undoOffer { forgetUndo(of: replaced) }
        undoOffer = offerUndo(of: change, id: celebration.id)
    }

    /// What a change grew, as a celebration with a new id: the skill, a badge or a moment, never a number. A new title
    /// has its own card (ADR-0055 §6).
    func makeCelebration(skill: Skill?, badge: String? = nil, moment: String? = nil) -> Celebration {
        celebrationCount += 1
        celebratedSkills[celebrationCount] = skill
        return Celebration(
            id: celebrationCount,
            skillText: skill.map(strings.strings.skillGrew),
            badgeText: badge,
            momentText: moment
        )
    }

    var saveFailedMessage: String {
        strings.text("Couldn't save. Please try again.")
    }

    /// Reads home again and shows it, unless a newer load has started meanwhile. Returns what it read either way, for a
    /// caller that needs this load's own answer (`open(_:)`), or `nil` if there was none.
    @discardableResult
    func load() async -> HomeOverview? {
        loadGeneration += 1
        let generation = loadGeneration
        loadsUnderWay += 1
        defer { loadsUnderWay -= 1 }
        do {
            guard let overview = try await useCases.getOverview.execute(
                childID: selectedChildID, worldID: viewedWorldID, on: now()
            ) else {
                guard generation == loadGeneration else { return nil }
                state = .failed(message: strings.text("No profile found."))
                return nil
            }
            // A card closed for a title above the one held, which an Undo took back, may come again.
            closedTitleCards = closedTitleCards.filter { id in
                (overview.catalog.title(id: id)?.order ?? 0) <= (overview.standing.title?.order ?? -1)
            }
            let titleCard = makeTitleCard(overview)
            let sagaOffer = titleCard == nil ? makeSagaOffer(overview) : nil
            let reminderOffer = titleCard == nil && sagaOffer == nil
                ? await makeReminderOffer(children: overview.profile.children, progress: overview.progress)
                : nil
            guard generation == loadGeneration else { return overview }
            self.titleCard = titleCard
            self.sagaOffer = sagaOffer
            self.reminderOffer = reminderOffer
            selectedChildID = overview.child.id
            viewedWorldID = overview.isShowingCurrentWorld ? nil : overview.shownWorld?.id
            self.overview = overview
            state = .loaded(makeContent(overview))
            return overview
        } catch {
            guard generation == loadGeneration else { return nil }
            // A home that loaded once stays as it was: what it shows is still the dad's saga, only not refreshed.
            if case .loaded = state { return nil }
            state = .failed(message: strings.text("Content failed to load."))
            return nil
        }
    }

    private func makeContent(_ overview: HomeOverview) -> HomeContent {
        let profile = overview.profile
        let child = overview.child
        let catalog = overview.catalog
        let adventure = overview.adventure
        let progress = overview.progress
        let hero = catalog.hero(for: profile)
        let childLine = "\(child.name) · \(strings.ageText(adventure.age))"
        let hasSiblings = profile.children.count > 1
        return HomeContent(
            heroTitle: hero?.title.resolved(for: locale) ?? strings.text("Hero"),
            heroTagline: child.isBorn ? hero?.tagline.resolved(for: locale) : nil,
            heroLook: HeroLook(look: hero?.look),
            heroSkin: SkinToneChoice(profile.dadSkinTone),
            heroAppearance: DadAppearanceChoice(profile.dadAppearance),
            heroGear: overview.equippedGear.compactMap { HeroGearLook(look: $0.look) },
            medalCount: progress.allDefeatedBossIDs.count,
            companionLine: hasSiblings ? profile.children.map(\.name).joined(separator: " · ") : childLine,
            childTabs: hasSiblings ? profile.children.map { ChildTab(id: $0.id, name: $0.name) } : [],
            companions: companions(overview),
            selectedChildID: child.id,
            selectedChildLine: hasSiblings ? childLine : nil,
            familyTitle: strings.text("My family"),
            settingsTitle: strings.text("Settings"),
            dadTitle: makeTitleLine(overview.standing),
            skills: makeSkillMarks(overview.skills),
            worldTitle: overview.shownWorld?.title.resolved(for: locale),
            worldTagline: overview.shownWorld?.tagline.resolved(for: locale),
            mapTitle: strings.text("World map"),
            backToCurrentTitle: overview.isShowingCurrentWorld
                ? nil
                : strings.text("Back to the current world"),
            emptyMessage: adventure.isBeyondContent
                ? strings.text("Adventures for your child's age are coming soon.")
                : nil,
            arrivalLine: child.isBorn ? nil : strings.text("When they arrive, untick “Not born yet” in My family."),
            cards: bossCards(overview.bosses, overview: overview) + questCards(overview),
            situational: situationalCards(overview),
            moments: momentsFormatter.section(for: child, age: adventure.age, catalog: catalog, progress: progress)
        )
    }
}
