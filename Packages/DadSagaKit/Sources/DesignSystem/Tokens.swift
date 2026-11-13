import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Colour tokens. Always use these instead of raw colours so light/dark stay consistent.
public enum DSColor {
    public static let background = Color(light: 0xFBF7F0, dark: 0x14161F)
    public static let surface = Color(light: 0xFFFFFF, dark: 0x1F2230)
    public static let textPrimary = Color(light: 0x1D1B26, dark: 0xF3F0EA)
    public static let textSecondary = Color(light: 0x6B6878, dark: 0xA6A3B3)
    /// Primary action colour.
    public static let accent = Color(light: 0x3B5BDB, dark: 0x7C93F5)
    /// XP bars and progress.
    public static let xp = Color(light: 0x0E9F6E, dark: 0x34D399)
    /// "Legendary moments" (firsts) and badges.
    public static let legendary = Color(light: 0xD99A00, dark: 0xFBBF24)
    /// Boss fights.
    public static let boss = Color(light: 0xC2410C, dark: 0xFB923C)

    // MARK: Hero avatar palette
    public static let heroSkin = Color(light: 0xF2C9A0, dark: 0xF2C9A0)
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
    public static let heroSkinShade = Color(light: 0xDFAE84, dark: 0xDFAE84)
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
    public static let card: CGFloat = 16
    public static let pill: CGFloat = 999
}

public enum DSFont {
    public static let title = Font.system(.title2, design: .rounded, weight: .bold)
    public static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
    public static let body = Font.system(.body, design: .rounded)
    public static let caption = Font.system(.caption, design: .rounded, weight: .medium)
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
