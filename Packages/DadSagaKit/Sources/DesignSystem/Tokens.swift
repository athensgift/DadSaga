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
