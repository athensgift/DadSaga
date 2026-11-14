import DesignSystem

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
        case .legendary: .legendary
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
