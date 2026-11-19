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

public struct HeroOption: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let tagline: String
    public let look: HeroLook
}
