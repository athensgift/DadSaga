/// A piece of earned gear as drawn on the hero. Built from the content's `look` names; unknown names are dropped.
public enum HeroGearLook: CaseIterable, Sendable {
    case burpCloth, burpClothGold, mug, thermos, duck, blocks, diaperBag, megaBag

    init?(look: String) {
        switch look {
        case "burpCloth": self = .burpCloth
        case "burpClothGold": self = .burpClothGold
        case "mug": self = .mug
        case "thermos": self = .thermos
        case "duck": self = .duck
        case "blocks": self = .blocks
        case "diaperBag": self = .diaperBag
        case "megaBag": self = .megaBag
        default: return nil
        }
    }
}
