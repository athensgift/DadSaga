import DesignSystem
import SwiftUI

/// Skin tones for every avatar (dad and children), light to deep: the same five-step scale emoji use.
public enum AvatarSkin: CaseIterable, Sendable {
    case light, mediumLight, medium, mediumDark, dark

    public var base: Color {
        switch self {
        case .light: Color(light: 0xF7DCC4, dark: 0xF7DCC4)
        case .mediumLight: Color(light: 0xF2C9A0, dark: 0xF2C9A0)
        case .medium: Color(light: 0xDBA77E, dark: 0xDBA77E)
        case .mediumDark: Color(light: 0xA9714A, dark: 0xA9714A)
        case .dark: Color(light: 0x6B4431, dark: 0x6B4431)
        }
    }

    /// Ears, nose and neck.
    var shade: Color {
        switch self {
        case .light: Color(light: 0xE8C0A0, dark: 0xE8C0A0)
        case .mediumLight: Color(light: 0xDFAE84, dark: 0xDFAE84)
        case .medium: Color(light: 0xC48C62, dark: 0xC48C62)
        case .mediumDark: Color(light: 0x8E5A37, dark: 0x8E5A37)
        case .dark: Color(light: 0x543322, dark: 0x543322)
        }
    }

    /// The hair colour that comes with this tone: the children's, and the dad's until he chooses (ADR-0044).
    var naturalHair: HeroAvatar.Features.HairColor {
        switch self {
        case .light, .mediumLight, .medium: .brown
        case .mediumDark, .dark: .black
        }
    }

    /// Hair and brows of the children.
    var hair: Color { naturalHair.color }

    var gradient: LinearGradient { heroGradient(base, shade) }
}

extension EnvironmentValues {
    /// Set by each avatar for the parts it draws.
    @Entry var avatarSkin: AvatarSkin = .mediumLight
}
