import Application
import Domain
import Foundation
import Localization
import Observation

/// Presenter for "Your hero": the dad changes his hero, skin tone and look after onboarding. Each change shows and is
/// stored at once, like the wardrobe beside it (ADR-0044 §2). Progress and wardrobe stay as they are (ADR-0030).
@MainActor
@Observable
public final class HeroSettingsViewModel {
    public private(set) var state: HeroSettingsViewState = .loading
    public private(set) var selectedHeroID: String?
    public private(set) var skinTone: SkinToneChoice = .mediumLight
    public private(set) var appearance: DadAppearanceChoice = .standard
    /// The menus of "Your look", with the current choice.
    public private(set) var looks: AppearanceSection?
    public private(set) var errorMessage: String?

    /// The chosen hero drawn large at the top of the page.
    public var previewLook: HeroLook? {
        guard case .loaded(let content) = state else { return nil }
        return content.picker.heroes.first { $0.id == selectedHeroID }?.look
    }

    private struct Selection: Equatable {
        var heroID: String
        var skinTone: SkinTone
        var appearance: DadAppearance
    }

    private let getHeroChoice: any GetHeroChoiceUseCase
    private let updateHero: any UpdateHeroUseCase
    private let locale: Locale
    private let now: Date
    private var options: [DadAppearanceOption] = []
    /// What is shown.
    private var current: Selection?
    /// What the store holds.
    private var stored: Selection?
    private var lastSave: Task<Void, Never>?
    /// Counts changes, so a failed save knows whether a newer change is on its way.
    private var generation = 0

    public init(
        getHeroChoice: any GetHeroChoiceUseCase,
        updateHero: any UpdateHeroUseCase,
        locale: Locale = .current,
        now: Date = .now
    ) {
        self.getHeroChoice = getHeroChoice
        self.updateHero = updateHero
        self.locale = locale
        self.now = now
    }

    public func onAppear() async {
        guard state == .loading else { return }
        do {
            guard let choice = try await getHeroChoice.execute() else {
                state = .failed(message: strings.text("No profile found."))
                return
            }
            options = choice.appearanceOptions
            let selection = Selection(heroID: choice.heroClassID, skinTone: choice.skinTone, appearance: choice.appearance)
            stored = selection
            show(selection)
            state = .loaded(HeroSettingsContent(
                title: strings.text("Your hero"),
                picker: HeroPickerContent.make(heroClasses: choice.heroClasses, locale: locale)
            ))
        } catch {
            state = .failed(message: strings.text("Content failed to load."))
        }
    }

    public func selectHero(id: String) async {
        await change { $0.heroID = id }
    }

    public func setSkinTone(_ tone: SkinToneChoice) async {
        await change { selection in
            selection.appearance = selection.appearance.changingSkinTone(from: selection.skinTone, to: tone.domain)
            selection.skinTone = tone.domain
        }
    }

    /// `rowID` is a part of the look and `optionID` one of its options; anything else is ignored.
    public func selectOption(rowID: String, optionID: String) async {
        guard let part = DadAppearance.Part(rawValue: rowID),
              let look = current?.appearance.choosing(optionID, for: part) else { return }
        await change { $0.appearance = look }
    }

    /// Shows the change, then stores the whole choice after any save already under way, so the store ends with the
    /// newest. A failed save puts the page back to what is stored, unless a newer change is on its way.
    private func change(_ edit: (inout Selection) -> Void) async {
        guard var changed = current else { return }
        edit(&changed)
        guard changed != current else { return }
        show(changed)
        errorMessage = nil
        generation += 1
        let thisChange = generation
        let useCase = updateHero
        let date = now
        let save = Task { [previous = lastSave] in
            await previous?.value
            do {
                try await useCase.execute(
                    heroClassID: changed.heroID, skinTone: changed.skinTone, appearance: changed.appearance, on: date
                )
                stored = changed
            } catch {
                guard thisChange == generation, let stored else { return }
                show(stored)
                errorMessage = strings.text("Couldn't save. Please try again.")
            }
        }
        lastSave = save
        await save.value
    }

    private func show(_ selection: Selection) {
        current = selection
        selectedHeroID = selection.heroID
        skinTone = SkinToneChoice(selection.skinTone)
        appearance = DadAppearanceChoice(selection.appearance)
        looks = AppearanceSection.make(options: options, appearance: selection.appearance, locale: locale)
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
    public let picker: HeroPickerContent
}
