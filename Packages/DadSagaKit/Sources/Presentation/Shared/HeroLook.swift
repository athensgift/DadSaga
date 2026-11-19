/// Which avatar a hero class is drawn with, from the content's `look` names. An unknown or missing look
/// (a hero class removed from the content, say) falls back to Super Dad, so the screen never breaks.
public enum HeroLook: Equatable, Sendable {
    case hero, cool, strong, smart, chef, fixer

    init(look: String?) {
        switch look {
        case "cool": self = .cool
        case "strong": self = .strong
        case "smart": self = .smart
        case "chef": self = .chef
        case "fixer": self = .fixer
        default: self = .hero
        }
    }
}
