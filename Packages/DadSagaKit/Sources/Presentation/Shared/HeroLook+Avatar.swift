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
