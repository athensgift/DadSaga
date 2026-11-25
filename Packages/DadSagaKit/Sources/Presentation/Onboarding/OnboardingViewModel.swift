import Application
import Domain
import Foundation
import Localization
import Observation

/// Presenter for onboarding: the dad's children (1 to 4) and whether he raises them with a partner, then his hero class
/// and skin tone.
@MainActor
@Observable
public final class OnboardingViewModel {
    public enum Step: Equatable, Sendable {
        case child, hero
    }

    public private(set) var state: OnboardingViewState = .loading
    public private(set) var step: Step = .child
    public private(set) var selectedHeroID: String?
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?
    public var family: FamilyDraft
    /// A child cannot be born in the future: now, as last read.
    public private(set) var latestBirthDate: Date

    /// The look the profile is created with: the standard one for the chosen skin tone (ADR-0044 §2).
    public var dadAppearance: DadAppearanceChoice {
        DadAppearanceChoice(.standard(for: family.dadSkinTone.domain))
    }

    public var canContinue: Bool {
        family.isComplete
    }

    public var canFinish: Bool {
        selectedHeroID != nil && !isSaving
    }

    private let loadCatalog: any LoadContentCatalogUseCase
    private let saveProfile: any SaveProfileUseCase
    private let locale: Locale
    private let now: @Sendable () -> Date
    /// The zone the date pickers draw in, and the one "today" is read in.
    public let timeZone: TimeZone
    private let onFinished: @MainActor () -> Void

    public init(
        loadCatalog: any LoadContentCatalogUseCase,
        saveProfile: any SaveProfileUseCase,
        locale: Locale = .current,
        now: @escaping @Sendable () -> Date = Date.init,
        timeZone: TimeZone = .autoupdatingCurrent,
        onFinished: @escaping @MainActor () -> Void
    ) {
        self.loadCatalog = loadCatalog
        self.saveProfile = saveProfile
        self.locale = locale
        self.now = now
        latestBirthDate = now()
        self.timeZone = timeZone
        self.onFinished = onFinished
        family = FamilyDraft(children: [ChildDraft(birthDay: CalendarDay(now(), in: timeZone))])
    }

    public func onAppear() async {
        guard state == .loading else { return }
        do {
            let catalog = try await loadCatalog.execute()
            state = .loaded(makeContent(from: catalog))
        } catch {
            state = .failed(LoadFailure(message: strings.text("Content failed to load."), retryTitle: strings.text("Try again")))
        }
    }

    /// "Try again", after the content failed to load.
    public func retry() async {
        guard case .failed = state else { return }
        state = .loading
        await onAppear()
    }

    public func continueToHero() {
        guard canContinue else { return }
        step = .hero
    }

    /// Back in the app, perhaps a day later: a child can be born today.
    public func appBecameActive() {
        latestBirthDate = now()
    }

    public func addChild() {
        latestBirthDate = now()
        family.addChild(birthDay: CalendarDay(latestBirthDate, in: timeZone))
    }

    public func removeChild(id: UUID) {
        family.removeChild(id: id)
    }

    public func backToChild() {
        step = .child
    }

    public func selectHero(id: String) {
        selectedHeroID = id
        errorMessage = nil
    }

    public func finish() async {
        guard let selectedHeroID, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        // The last error goes as the next try starts, so the same error again is read out again.
        errorMessage = nil
        do {
            // Who this player is, from now on the author of every entry (ADR-0065 §5).
            let profile = PlayerProfile(
                id: UUID(),
                children: family.children.map(\.child),
                heroClassID: selectedHeroID,
                dadSkinTone: family.dadSkinTone.domain,
                hasPartner: family.hasPartner
            )
            try await saveProfile.execute(profile, on: now())
            onFinished()
        } catch {
            errorMessage = strings.text("Couldn't save. Please try again.")
        }
    }

    private func makeContent(from catalog: ContentCatalog) -> OnboardingContent {
        OnboardingContent(
            welcomeTitle: strings.text("Welcome, hero"),
            welcomeSubtitle: strings.text("Every saga needs companions. Tell us about your kids."),
            childEditor: ChildEditorLabels.make(locale: locale),
            partner: PartnerRowLabels.make(locale: locale),
            continueTitle: strings.text("Continue"),
            importTitle: strings.text("Import data"),
            heroTitle: strings.text("Choose your hero"),
            finishTitle: strings.text("Start the adventure"),
            hero: HeroPickerContent.make(heroClasses: catalog.heroClasses, locale: locale)
        )
    }

    private var strings: Strings { Strings(locale: locale) }
}
