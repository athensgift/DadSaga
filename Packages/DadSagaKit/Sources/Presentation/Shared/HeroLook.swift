/// Which avatar a hero class is drawn with. Unknown class ids fall back to Super Dad,
/// so content added or renamed later never breaks the screen.
public enum HeroLook: Equatable, Sendable {
    case hero, cool, strong, smart, chef, fixer

    init(heroClassID: String) {
        switch heroClassID {
        case "h-cool": self = .cool
        case "h-strong": self = .strong
        case "h-smart": self = .smart
        case "h-chef": self = .chef
        case "h-fixer": self = .fixer
        default: self = .hero
        }
    }
}
