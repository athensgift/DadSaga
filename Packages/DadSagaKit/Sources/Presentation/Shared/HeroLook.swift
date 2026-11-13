/// Which avatar a hero class is drawn with. Unknown class ids fall back to the knight,
/// so content added later never breaks the screen.
public enum HeroLook: Equatable, Sendable {
    case knight, mage, ranger

    init(heroClassID: String) {
        switch heroClassID {
        case "h-mage": self = .mage
        case "h-ranger": self = .ranger
        default: self = .knight
        }
    }
}
