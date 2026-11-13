import DesignSystem

extension HeroLook {
    var avatarStyle: HeroAvatar.Style {
        switch self {
        case .knight: .knight
        case .mage: .mage
        case .ranger: .ranger
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
