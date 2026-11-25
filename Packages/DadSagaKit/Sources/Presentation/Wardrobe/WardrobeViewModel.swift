import Application
import Domain
import Foundation
import Localization
import Observation

/// Presenter for the wardrobe: choose, per slot, which earned item the hero wears, or nothing, or "automatic". Only
/// what the hero has is shown, without XP: nothing hints at what the next title brings (ADR-0055 §8).
@MainActor
@Observable
public final class WardrobeViewModel {
    public struct UseCases: Sendable {
        let getWardrobe: any GetWardrobeUseCase
        let setChoice: any SetOutfitChoiceUseCase

        public init(getWardrobe: any GetWardrobeUseCase, setChoice: any SetOutfitChoiceUseCase) {
            self.getWardrobe = getWardrobe
            self.setChoice = setChoice
        }
    }

    public private(set) var state: WardrobeViewState = .loading
    public private(set) var errorMessage: String?

    private static let automaticID = "automatic"
    private static let hiddenID = "hidden"

    private let useCases: UseCases
    private let locale: Locale
    private var wardrobe: Wardrobe?
    /// Slots with a save under way, and the choice tapped meanwhile, which is saved next: one save at a time for each
    /// slot, so the last tap is the one stored.
    private var savingSlots: Set<Skill> = []
    private var nextChoices: [Skill: OutfitChoice] = [:]

    public init(useCases: UseCases, locale: Locale = .current) {
        self.useCases = useCases
        self.locale = locale
    }

    public func onAppear() async {
        do {
            wardrobe = try await useCases.getWardrobe.execute()
            rebuild()
        } catch {
            state = .failed(message: strings.text("The wardrobe failed to load."))
        }
    }

    /// Wears an option. Only an item the hero has can be chosen.
    public func select(slotID: String, optionID: String) async {
        guard let skill = Skill(rawValue: slotID), let wardrobe else { return }
        let choice: OutfitChoice
        switch optionID {
        case Self.automaticID: choice = .automatic
        case Self.hiddenID: choice = .hidden
        default:
            guard wardrobe.isEarned(itemID: optionID, skill: skill) else { return }
            choice = .item(optionID)
        }
        // Only this slot changes on screen, so a reply for another slot never undoes a tap made meanwhile.
        let stored = wardrobe.outfit.choices[skill]
        show(choice == .automatic ? nil : choice, in: skill)
        // The last error goes as the next try starts, so the same error again is read out again.
        errorMessage = nil
        guard savingSlots.insert(skill).inserted else {
            nextChoices[skill] = choice
            return
        }
        defer { savingSlots.remove(skill) }
        await save(choice, in: skill, over: stored)
    }

    /// Saves the choice, then the one tapped meanwhile, until none is waiting. Only the last one's reply shows: what is
    /// stored then, the one before it if it failed.
    private func save(_ choice: OutfitChoice, in skill: Skill, over stored: OutfitChoice?) async {
        var stored = stored
        var next: OutfitChoice? = choice
        while let choice = next {
            var didFail = false
            do {
                stored = try await useCases.setChoice.execute(skill: skill, choice: choice).choices[skill]
            } catch {
                didFail = true
            }
            next = nextChoices.removeValue(forKey: skill)
            guard next == nil else { continue }
            show(stored, in: skill)
            if didFail { errorMessage = strings.text("Couldn't save. Please try again.") }
        }
    }

    private func show(_ choice: OutfitChoice?, in skill: Skill) {
        wardrobe?.outfit.choices[skill] = choice
        rebuild()
    }

    // MARK: Building

    private func rebuild() {
        guard let wardrobe else { return }
        let profile = wardrobe.profile
        state = .loaded(
            WardrobeContent(
                title: strings.text("Wardrobe"),
                heroLook: HeroLook(look: wardrobe.hero?.look),
                heroSkin: SkinToneChoice(profile?.dadSkinTone ?? .mediumLight),
                heroAppearance: profile.map { DadAppearanceChoice($0.dadAppearance) } ?? .standard,
                gear: wardrobe.equipped.compactMap { HeroGearLook(look: $0.look) },
                medalCount: wardrobe.progress.allDefeatedBossIDs.count,
                slots: Skill.allCases.compactMap { slot(for: $0, in: wardrobe) },
                emptyMessage: wardrobe.earned.isEmpty ? strings.text("What your hero earns will be here.") : nil,
                footnote: strings.text("Your titles bring these. What you have stays yours.")
            )
        )
    }

    /// `nil` while the hero has nothing for this slot.
    private func slot(for skill: Skill, in wardrobe: Wardrobe) -> WardrobeSlot? {
        let items = wardrobe.earned.filter { $0.skill == skill }
        guard !items.isEmpty else { return nil }
        let choice = wardrobe.outfit.choice(for: skill)
        var options = [
            WardrobeOption(
                id: Self.automaticID,
                title: strings.text("Automatic"),
                detail: strings.text("The best one"),
                isSelected: choice == .automatic,
                item: nil
            ),
            WardrobeOption(
                id: Self.hiddenID,
                title: strings.text("Nothing"),
                detail: nil,
                isSelected: choice == .hidden,
                item: nil
            )
        ]
        // An item chosen before a rename is still the one shown as chosen (ADR-0048 §5).
        let chosenID: String? = if case .item(let id) = choice { id } else { nil }
        options += items.map { item in
            WardrobeOption(
                id: item.id,
                title: item.title.resolved(for: locale),
                detail: nil,
                isSelected: chosenID.map(item.has(id:)) ?? false,
                item: HeroGearLook(look: item.look)
            )
        }
        return WardrobeSlot(id: skill.rawValue, title: strings.skill(skill), symbol: skill.symbol, options: options)
    }

    private var strings: Strings { Strings(locale: locale) }
}

public enum WardrobeViewState: Equatable, Sendable {
    case loading
    case loaded(WardrobeContent)
    case failed(message: String)
}

public struct WardrobeContent: Equatable, Sendable {
    public let title: String
    public let heroLook: HeroLook
    public let heroSkin: SkinToneChoice
    public let heroAppearance: DadAppearanceChoice
    /// What the hero wears with the current choices.
    public let gear: [HeroGearLook]
    public let medalCount: Int
    /// One per skill the hero has an item for.
    public let slots: [WardrobeSlot]
    /// Set while the hero has nothing yet.
    public let emptyMessage: String?
    public let footnote: String
}

public struct WardrobeSlot: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let symbol: String
    /// Automatic, nothing, then every item the hero has for the slot.
    public let options: [WardrobeOption]
}

public struct WardrobeOption: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    /// e.g. "The best one", for "automatic".
    public let detail: String?
    public let isSelected: Bool
    /// The item's drawing, for real items; `nil` for "automatic" and "nothing".
    public let item: HeroGearLook?
}
