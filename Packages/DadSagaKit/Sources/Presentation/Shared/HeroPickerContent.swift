import Domain
import Foundation
import Localization

/// Text and heroes for the hero picker, shared by onboarding and the "Your hero" page.
public struct HeroPickerContent: Equatable, Sendable {
    public let subtitle: String
    public let skinToneLabel: String
    /// Accessibility names of the tones, in `SkinToneChoice.allCases` order.
    public let skinToneNames: [String]
    public let heroes: [HeroOption]

    static func make(heroClasses: [HeroClass], locale: Locale) -> HeroPickerContent {
        let strings = Strings(locale: locale)
        return HeroPickerContent(
            subtitle: strings.text("It's only your look. Every hero is equally strong."),
            skinToneLabel: strings.text("Your skin tone"),
            skinToneNames: ChildEditorLabels.make(locale: locale).skinToneNames,
            heroes: heroClasses.map { hero in
                HeroOption(
                    id: hero.id,
                    title: hero.title.resolved(for: locale),
                    tagline: hero.tagline.resolved(for: locale),
                    look: HeroLook(look: hero.look)
                )
            }
        )
    }
}

/// "Your look" on the hero page: one menu per part of the dad's look (ADR-0044 §2).
public struct AppearanceSection: Equatable, Sendable {
    public let title: String
    public let rows: [AppearanceRow]

    /// The rows in the Domain's part order, each listing the content's names in the content's order.
    static func make(options: [DadAppearanceOption], appearance: DadAppearance, locale: Locale) -> AppearanceSection {
        let strings = Strings(locale: locale)
        return AppearanceSection(
            title: strings.text("Your look"),
            rows: DadAppearance.Part.allCases.map { part in
                AppearanceRow(
                    id: part.rawValue,
                    title: strings.text(part.title),
                    options: options.filter { $0.part == part }.map {
                        AppearanceOptionModel(id: $0.id, title: $0.title.resolved(for: locale))
                    },
                    selectedID: appearance.optionID(for: part)
                )
            }
        )
    }
}

/// One part of the look: its name, its options and the one chosen.
public struct AppearanceRow: Equatable, Identifiable, Sendable {
    /// The part, as the content names it: "hair", "hairColor", "beard" or "glasses".
    public let id: String
    public let title: String
    public let options: [AppearanceOptionModel]
    public let selectedID: String
}

public struct AppearanceOptionModel: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
}

private extension DadAppearance.Part {
    /// The row's name in the String Catalog.
    var title: String.LocalizationValue {
        switch self {
        case .hair: "Hair"
        case .hairColor: "Hair colour"
        case .beard: "Beard"
        case .glasses: "Glasses"
        }
    }
}

public struct HeroOption: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let tagline: String
    public let look: HeroLook
}
