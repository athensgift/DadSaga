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
        hair = Hair(look.hair)
        hairColor = HairColor(look.hairColor)
        beard = Beard(look.beard)
        glasses = Glasses(look.glasses)
    }
}

private extension DadAppearanceChoice.Hair {
    init(_ hair: DadAppearance.Hair) {
        switch hair {
        case .short: self = .short
        case .curly: self = .curly
        case .long: self = .long
        case .shaved: self = .shaved
        }
    }
}

private extension DadAppearanceChoice.HairColor {
    init(_ color: DadAppearance.HairColor) {
        switch color {
        case .black: self = .black
        case .brown: self = .brown
        case .blond: self = .blond
        case .red: self = .red
        case .grey: self = .grey
        }
    }
}

private extension DadAppearanceChoice.Beard {
    init(_ beard: DadAppearance.Beard) {
        switch beard {
        case .none: self = .none
        case .short: self = .short
        case .full: self = .full
        }
    }
}

private extension DadAppearanceChoice.Glasses {
    init(_ glasses: DadAppearance.Glasses) {
        switch glasses {
        case .none: self = .none
        case .round: self = .round
        }
    }
}
