import Application
import Domain
import Foundation
import Localization
import Observation

/// Presenter for "Your hero": the dad changes his hero and skin tone after onboarding. Progress and wardrobe stay as
/// they are (ADR-0030).
@MainActor
@Observable
public final class HeroSettingsViewModel {
    public private(set) var state: HeroSettingsViewState = .loading
    public private(set) var selectedHeroID: String?
    public var skinTone: SkinToneChoice = .mediumLight
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?

    /// Something changed and nothing is being saved.
    public var canSave: Bool {
        guard let saved, let selectedHeroID, !isSaving else { return false }
        return selectedHeroID != saved.heroID || skinTone != saved.skinTone
    }

    private let getHeroChoice: any GetHeroChoiceUseCase
    private let updateHero: any UpdateHeroUseCase
    private let locale: Locale
    private let now: Date
    private let onSaved: @MainActor () -> Void
    private var saved: (heroID: String, skinTone: SkinToneChoice)?

    public init(
        getHeroChoice: any GetHeroChoiceUseCase,
        updateHero: any UpdateHeroUseCase,
        locale: Locale = .current,
        now: Date = .now,
        onSaved: @escaping @MainActor () -> Void
    ) {
        self.getHeroChoice = getHeroChoice
        self.updateHero = updateHero
        self.locale = locale
        self.now = now
        self.onSaved = onSaved
    }

    public func onAppear() async {
        guard state == .loading else { return }
        do {
            guard let choice = try await getHeroChoice.execute() else {
                state = .failed(message: strings.text("No profile found."))
                return
            }
            let tone = SkinToneChoice(choice.skinTone)
            saved = (choice.heroClassID, tone)
            selectedHeroID = choice.heroClassID
            skinTone = tone
            state = .loaded(HeroSettingsContent(
                title: strings.text("Your hero"),
                saveTitle: strings.text("Save"),
                picker: HeroPickerContent.make(heroClasses: choice.heroClasses, locale: locale)
            ))
        } catch {
            state = .failed(message: strings.text("Content failed to load."))
        }
    }

    public func selectHero(id: String) {
        selectedHeroID = id
        errorMessage = nil
    }

    public func save() async {
        guard canSave, let selectedHeroID else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await updateHero.execute(heroClassID: selectedHeroID, skinTone: skinTone.domain, on: now)
            saved = (selectedHeroID, skinTone)
            errorMessage = nil
            onSaved()
        } catch {
            errorMessage = strings.text("Couldn't save. Please try again.")
        }
    }

    private var strings: Strings { Strings(locale: locale) }
}

public enum HeroSettingsViewState: Equatable, Sendable {
    case loading
    case loaded(HeroSettingsContent)
    case failed(message: String)
}

public struct HeroSettingsContent: Equatable, Sendable {
    public let title: String
    public let saveTitle: String
    public let picker: HeroPickerContent
}
