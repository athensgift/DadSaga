import Application
import Domain
import Foundation
import Localization
import Observation

/// Presenter for the wardrobe: choose, per slot, which earned item the hero wears, or nothing, or "automatic".
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

    /// Wears an option. Locked items cannot be chosen.
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
        let previous = wardrobe.outfit.choices[skill]
        self.wardrobe?.outfit.choices[skill] = choice == .automatic ? nil : choice
        rebuild()
        do {
            let saved = try await useCases.setChoice.execute(skill: skill, choice: choice)
            self.wardrobe?.outfit.choices[skill] = saved.choices[skill]
            errorMessage = nil
        } catch {
            self.wardrobe?.outfit.choices[skill] = previous
            errorMessage = strings.text("Couldn't save. Please try again.")
        }
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
                gear: wardrobe.equipped.compactMap { HeroGearLook(look: $0.look) },
                medalCount: wardrobe.progress.allDefeatedBossIDs.count,
                slots: Skill.allCases.map { slot(for: $0, in: wardrobe) },
                footnote: strings.text("You earn items with each skill's XP. What you earn stays yours.")
            )
        )
    }

    private func slot(for skill: Skill, in wardrobe: Wardrobe) -> WardrobeSlot {
        let xp = wardrobe.progress.skillXP[skill, default: 0]
        let items = wardrobe.gear.filter { $0.skill == skill }.sorted { $0.minXP < $1.minXP }
        let choice = wardrobe.outfit.choice(for: skill)
        var options = [
            WardrobeOption(
                id: Self.automaticID,
                title: strings.text("Automatic"),
                detail: strings.text("The best one"),
                isSelected: choice == .automatic,
                isLocked: false,
                progress: nil,
                item: nil
            ),
            WardrobeOption(
                id: Self.hiddenID,
                title: strings.text("Nothing"),
                detail: nil,
                isSelected: choice == .hidden,
                isLocked: false,
                progress: nil,
                item: nil
            )
        ]
        options += items.map { item in
            let isLocked = item.minXP > xp
            return WardrobeOption(
                id: item.id,
                title: item.title.resolved(for: locale),
                detail: isLocked ? "\(xp) / \(item.minXP) XP" : nil,
                isSelected: choice == .item(item.id),
                isLocked: isLocked,
                progress: isLocked ? Double(xp) / Double(item.minXP) : nil,
                item: HeroGearLook(look: item.look)
            )
        }
        return WardrobeSlot(
            id: skill.rawValue,
            title: strings.skill(skill),
            symbol: skill.symbol,
            xpText: "\(xp) XP",
            options: options
        )
    }

    private var strings: Strings { Strings(locale: locale) }
}

/// Identified by object, so home can present it with `sheet(item:)`.
extension WardrobeViewModel: Identifiable {}

public enum WardrobeViewState: Equatable, Sendable {
    case loading
    case loaded(WardrobeContent)
    case failed(message: String)
}

public struct WardrobeContent: Equatable, Sendable {
    public let title: String
    public let heroLook: HeroLook
    public let heroSkin: SkinToneChoice
    /// What the hero wears with the current choices.
    public let gear: [HeroGearLook]
    public let medalCount: Int
    /// One per skill.
    public let slots: [WardrobeSlot]
    public let footnote: String
}

public struct WardrobeSlot: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let symbol: String
    /// The skill's XP, e.g. "120 XP".
    public let xpText: String
    /// Automatic, nothing, then every item of the slot, earned or not.
    public let options: [WardrobeOption]
}

public struct WardrobeOption: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    /// The skill's XP towards a locked item, e.g. "120 / 200 XP".
    public let detail: String?
    public let isSelected: Bool
    public let isLocked: Bool
    /// How far the skill is towards a locked item, 0 to 1. `nil` when nothing is locked.
    public let progress: Double?
    /// The item's drawing, for real items; `nil` for "automatic" and "nothing".
    public let item: HeroGearLook?
}
