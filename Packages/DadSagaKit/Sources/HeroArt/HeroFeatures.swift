import DesignSystem
import SwiftUI

/// The dad's own features: hair, its colour, beard and glasses (ADR-0044). `.standard` is how every dad was drawn
/// before he could choose.
public struct HeroFeatures: Equatable, Sendable {
    public enum Hair: Sendable, CaseIterable { case short, curly, long, shaved }
    public enum HairColor: Sendable, CaseIterable { case black, brown, blond, red, grey }
    public enum Beard: Sendable, CaseIterable { case none, short, full }
    public enum Glasses: Sendable, CaseIterable { case none, round }

    public var hair: Hair
    public var hairColor: HairColor
    public var beard: Beard
    public var glasses: Glasses

    public init(hair: Hair = .short, hairColor: HairColor = .brown, beard: Beard = .full, glasses: Glasses = .none) {
        self.hair = hair
        self.hairColor = hairColor
        self.beard = beard
        self.glasses = glasses
    }

    public static let standard = HeroFeatures()
}

extension HeroFeatures.HairColor {
    /// Hair, brows and beard. Fixed art colours, like the skin tones: black and brown are the two the avatars always
    /// had; blond, red and grey read on all five skin tones.
    var color: Color {
        switch self {
        case .black: Color(light: 0x2B1E17, dark: 0x3A2A20)
        case .brown: DSColor.heroBeard
        case .blond: Color(light: 0xC08F45, dark: 0xD0A055)
        case .red: Color(light: 0xA0482A, dark: 0xB5573A)
        case .grey: Color(light: 0x8C8C92, dark: 0xA3A3A9)
        }
    }
}

extension HeroAvatar.Style {
    /// Where the archetype meets the dad's choice, the archetype wins: Smart Dad always wears his round glasses and
    /// Cool Dad's shades cover any glasses.
    func wornGlasses(_ choice: HeroFeatures.Glasses) -> HeroFeatures.Glasses {
        switch self {
        case .cool: .none
        case .smart: .round
        default: choice
        }
    }
}

extension EnvironmentValues {
    /// Set by `HeroAvatar` for the parts it draws.
    @Entry var heroFeatures = HeroFeatures.standard
}
