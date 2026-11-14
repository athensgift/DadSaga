import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Colour tokens. Always use these instead of raw colours so light/dark stay consistent.
/// Backgrounds and text use the system's semantic colours, so they follow light/dark mode, Increase Contrast and
/// the Liquid Glass material the way Apple's own apps do (ADR-0011).
public enum DSColor {
    #if canImport(UIKit)
    public static let background = Color(uiColor: .systemGroupedBackground)
    public static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    public static let textPrimary = Color(uiColor: .label)
    public static let textSecondary = Color(uiColor: .secondaryLabel)
    #else
    public static let background = Color(nsColor: .windowBackgroundColor)
    public static let surface = Color(nsColor: .controlBackgroundColor)
    public static let textPrimary = Color(nsColor: .labelColor)
    public static let textSecondary = Color(nsColor: .secondaryLabelColor)
    #endif
    /// Primary action colour.
    public static let accent = Color(light: 0x3B5BDB, dark: 0x7C93F5)
    /// XP bars and progress.
    public static let xp = Color(light: 0x0E9F6E, dark: 0x34D399)
    /// "Legendary moments" (firsts) and badges.
    public static let legendary = Color(light: 0xD99A00, dark: 0xFBBF24)
    /// Boss fights.
    public static let boss = Color(light: 0xC2410C, dark: 0xFB923C)

    // MARK: Hero avatar palette
    public static let heroBeard = Color(light: 0x5B3A29, dark: 0x7A5238)
    /// Eyes and other fine dark details.
    public static let heroInk = Color(light: 0x1D1B26, dark: 0x1D1B26)
    public static let heroHighlight = Color(light: 0xFFFFFF, dark: 0xFFFFFF)
    /// Trousers, boots and belt.
    public static let heroCloth = Color(light: 0x2E3142, dark: 0x4A4E63)
    public static let heroSteel = Color(light: 0xA9B4C2, dark: 0xC5CEDA)
    public static let heroWood = Color(light: 0x8B5E3C, dark: 0xA9764D)
    public static let heroMage = Color(light: 0x7B3FE4, dark: 0xA78BFA)
    public static let heroRanger = Color(light: 0x2F7D4F, dark: 0x3FA56B)
    public static let heroTeal = Color(light: 0x0E9AA7, dark: 0x2CC4D1)
    public static let heroTealShade = Color(light: 0x0A6C75, dark: 0x1593A0)
    public static let heroChef = Color(light: 0xFFFFFF, dark: 0xF3F0EA)
    public static let heroChefShade = Color(light: 0xD5CFC2, dark: 0xB9B3A6)
    public static let heroBlush = Color(light: 0xE8907A, dark: 0xE8907A)
    public static let heroSteelShade = Color(light: 0x7C8796, dark: 0x8E99A8)
    public static let heroLeather = Color(light: 0x6B4423, dark: 0x8A5A30)
    public static let heroKnightShade = Color(light: 0x2A429F, dark: 0x5870D0)
    public static let heroMageShade = Color(light: 0x5527A8, dark: 0x7C5CD6)
    public static let heroRangerShade = Color(light: 0x1F5A37, dark: 0x2C7A4C)
    public static let heroCapeShade = Color(light: 0x8F2F08, dark: 0xC96A2A)
}

public enum DSSpacing {
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 16
    public static let l: CGFloat = 24
    public static let xl: CGFloat = 32
}

public enum DSRadius {
    /// Cards and grouped panels. Always draw with `style: .continuous`.
    public static let card: CGFloat = 22
    /// Small icon tiles inside cards: concentric with `card` at `DSSpacing.m` inset.
    public static let tile: CGFloat = 10
}

/// Text styles. System text styles so Dynamic Type works everywhere; rounded only for display text.
public enum DSFont {
    public static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    public static let title = Font.system(.title2, design: .rounded, weight: .bold)
    public static let headline = Font.system(.headline)
    public static let body = Font.system(.body)
    public static let subheadline = Font.system(.subheadline)
    public static let caption = Font.system(.caption, weight: .medium)
}

extension Color {
    /// A colour that adapts to light/dark mode, from 0xRRGGBB values.
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(rgb: isDark ? dark : light)
        })
        #endif
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#elseif canImport(AppKit)
private extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif
