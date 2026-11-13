import Application
import Domain
import Foundation
import Observation

/// Presenter for onboarding: the child's name and birth date, then the dad's hero class.
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
    public var childName = ""
    public var birthDate: Date
    /// A child cannot be born in the future.
    public let latestBirthDate: Date

    public var canContinue: Bool {
        !childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        birthDate = now
        latestBirthDate = now
    }

    public func onAppear() async {
        guard state == .loading else { return }
        do {
            let catalog = try await loadCatalog.execute()
            state = .loaded(makeContent(from: catalog))
        } catch {
            state = .failed(message: text(el: "Το περιεχόμενο δεν φόρτωσε.", en: "Content failed to load."))
        }
    }

    public func continueToHero() {
        guard canContinue else { return }
        step = .hero
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
            let profile = PlayerProfile(child: Child(name: childName, birthDate: birthDate), heroClassID: selectedHeroID)
            try await saveProfile.execute(profile, on: latestBirthDate)
            onFinished()
        } catch {
            errorMessage = text(el: "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.", en: "Couldn't save. Please try again.")
        }
    }

    private func makeContent(from catalog: ContentCatalog) -> OnboardingContent {
        OnboardingContent(
            welcomeTitle: text(el: "Καλώς ήρθες, ήρωα", en: "Welcome, hero"),
            welcomeSubtitle: text(
                el: "Κάθε έπος θέλει έναν σύντροφο. Ποιος είναι ο δικός σου;",
                en: "Every saga needs a companion. Who is yours?"
            ),
            namePlaceholder: text(el: "Όνομα παιδιού", en: "Child's name"),
            birthDateLabel: text(el: "Ημερομηνία γέννησης", en: "Date of birth"),
            continueTitle: text(el: "Συνέχεια", en: "Continue"),
            heroTitle: text(el: "Διάλεξε τον ήρωά σου", en: "Choose your hero"),
            heroSubtitle: text(
                el: "Είναι μόνο η εμφάνισή σου. Όλοι οι ήρωες είναι το ίδιο δυνατοί.",
                en: "It's only your look. Every hero is equally strong."
            ),
            finishTitle: text(el: "Ξεκίνα την περιπέτεια", en: "Start the adventure"),
            backTitle: text(el: "Πίσω", en: "Back"),
            heroes: catalog.heroClasses.map { hero in
                HeroOption(
                    id: hero.id,
                    title: hero.title.resolved(for: locale),
                    tagline: hero.tagline.resolved(for: locale),
                    look: HeroLook(heroClassID: hero.id)
                )
            }
        )
    }

    private func text(el: String, en: String) -> String {
        LocalizedText(el: el, en: en).resolved(for: locale)
    }
}
