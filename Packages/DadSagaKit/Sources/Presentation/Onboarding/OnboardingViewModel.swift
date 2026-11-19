import Application
import Domain
import Foundation
import Localization
import Observation

/// Presenter for onboarding: the dad's children (1 to 4), then his hero class and skin tone.
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
    /// A child cannot be born in the future.
    public let latestBirthDate: Date

    public var canContinue: Bool {
        family.isComplete
    }

    public var canFinish: Bool {
        selectedHeroID != nil && !isSaving
    }

    private let loadCatalog: any LoadContentCatalogUseCase
    private let saveProfile: any SaveProfileUseCase
    private let locale: Locale
    private let onFinished: @MainActor () -> Void

    public init(
        loadCatalog: any LoadContentCatalogUseCase,
        saveProfile: any SaveProfileUseCase,
        locale: Locale = .current,
        now: Date = .now,
        onFinished: @escaping @MainActor () -> Void
    ) {
        self.loadCatalog = loadCatalog
        self.saveProfile = saveProfile
        self.locale = locale
        self.onFinished = onFinished
        family = FamilyDraft(children: [ChildDraft(birthDate: now)])
        latestBirthDate = now
    }

    public func onAppear() async {
        guard state == .loading else { return }
        do {
            let catalog = try await loadCatalog.execute()
            state = .loaded(makeContent(from: catalog))
        } catch {
            state = .failed(message: strings.text("Content failed to load."))
        }
    }

    public func continueToHero() {
        guard canContinue else { return }
        step = .hero
    }

    public func addChild() {
        family.addChild(birthDate: latestBirthDate)
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
        do {
            let profile = PlayerProfile(
                children: family.children.map(\.child),
                heroClassID: selectedHeroID,
                dadSkinTone: family.dadSkinTone.domain
            )
            try await saveProfile.execute(profile, on: latestBirthDate)
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
            dadSkinToneLabel: strings.text("Your skin tone"),
            continueTitle: strings.text("Continue"),
            heroTitle: strings.text("Choose your hero"),
            heroSubtitle: strings.text("It's only your look. Every hero is equally strong."),
            finishTitle: strings.text("Start the adventure"),
            heroes: catalog.heroClasses.map { hero in
                HeroOption(
                    id: hero.id,
                    title: hero.title.resolved(for: locale),
                    tagline: hero.tagline.resolved(for: locale),
                    look: HeroLook(look: hero.look)
                )
            }
        )
    }

    private var strings: Strings { Strings(locale: locale) }
}
