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
