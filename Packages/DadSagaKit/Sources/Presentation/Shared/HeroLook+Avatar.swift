import DesignSystem
import HeroArt

extension HeroLook {
    var avatarStyle: HeroAvatar.Style {
        switch self {
        case .hero: .hero
        case .cool: .cool
        case .strong: .strong
        case .smart: .smart
        case .chef: .chef
        case .fixer: .fixer
        }
    }
}

extension CardModel.Kind {
    var cardStyle: QuestCard.Style {
        switch self {
        case .quest: .quest
        case .boss: .boss
        }
    }
}

extension SkinToneChoice {
    var avatarSkin: AvatarSkin {
        switch self {
        case .light: .light
        case .mediumLight: .mediumLight
        case .medium: .medium
        case .mediumDark: .mediumDark
        case .dark: .dark
        }
    }
}

extension DadAppearanceChoice {
    var avatarFeatures: HeroFeatures {
        HeroFeatures(hair: hair.avatar, hairColor: hairColor.avatar, beard: beard.avatar, glasses: glasses.avatar)
    }
}

private extension DadAppearanceChoice.Hair {
    var avatar: HeroFeatures.Hair {
        switch self {
        case .short: .short
        case .curly: .curly
        case .long: .long
        case .shaved: .shaved
        }
    }
}

private extension DadAppearanceChoice.HairColor {
    var avatar: HeroFeatures.HairColor {
        switch self {
        case .black: .black
        case .brown: .brown
        case .blond: .blond
        case .red: .red
        case .grey: .grey
        }
    }
}

private extension DadAppearanceChoice.Beard {
    var avatar: HeroFeatures.Beard {
        switch self {
        case .none: .none
        case .short: .short
        case .full: .full
        }
    }
}

private extension DadAppearanceChoice.Glasses {
    var avatar: HeroFeatures.Glasses {
        switch self {
        case .none: .none
        case .round: .round
        }
    }
}

extension CompanionStage {
    var avatarStage: ChildAvatar.Stage {
        switch self {
        case .baby: .baby
        case .toddler: .toddler
        case .preschooler: .preschooler
        case .kid: .kid
        }
    }
}

extension GenderChoice {
    var avatarGender: ChildAvatar.Gender {
        switch self {
        case .boy: .boy
        case .girl: .girl
        }
    }
}

extension HeroGearLook {
    var heroItem: HeroItem {
        switch self {
        case .burpCloth: .burpCloth
        case .burpClothGold: .burpClothGold
        case .mug: .mug
        case .thermos: .thermos
        case .duck: .duck
        case .blocks: .blocks
        case .diaperBag: .diaperBag
        case .megaBag: .megaBag
        }
    }
}

extension Set where Element == CompanionTrait {
    var avatarTraits: ChildAvatar.Traits {
        reduce(into: []) { traits, trait in
            switch trait {
            case .smile: traits.insert(.smile)
            case .tooth: traits.insert(.tooth)
            case .walks: traits.insert(.walks)
            case .partyHat: traits.insert(.partyHat)
            }
        }
    }
}
