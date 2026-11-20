import Domain

/// The dad's look as the screens draw it (ADR-0044): the display side of `DadAppearance`, as `SkinToneChoice` is of
/// `SkinTone`.
public struct DadAppearanceChoice: Equatable, Sendable {
    public enum Hair: Sendable { case short, curly, long, shaved }
    public enum HairColor: Sendable { case black, brown, blond, red, grey }
    public enum Beard: Sendable { case none, short, full }
    public enum Glasses: Sendable { case none, round }

    public var hair: Hair
    public var hairColor: HairColor
    public var beard: Beard
    public var glasses: Glasses

    public static let standard = DadAppearanceChoice(DadAppearance())
}

extension DadAppearanceChoice {
    init(_ look: DadAppearance) {
        hair = switch look.hair {
        case .short: .short
        case .curly: .curly
        case .long: .long
        case .shaved: .shaved
        }
        hairColor = switch look.hairColor {
        case .black: .black
        case .brown: .brown
        case .blond: .blond
        case .red: .red
        case .grey: .grey
        }
        beard = switch look.beard {
        case .none: .none
        case .short: .short
        case .full: .full
        }
        glasses = switch look.glasses {
        case .none: .none
        case .round: .round
        }
    }
}
