import SwiftUI

/// Tokens for the saga film's cards (ADR-0037 §2). A film is a fixed dark canvas, not a screen: its colours never
/// follow light or dark mode, and its type and spacing are sized from the frame, never from Dynamic Type.
public enum DSFilm {
    // MARK: Colours (values and the contrast rule in `DSFilmInk`)

    /// What a card of words is drawn on.
    public static let ground = Color(rgb: DSFilmInk.ground)
    public static let text = Color(rgb: DSFilmInk.text)
    public static let secondaryText = Color(rgb: DSFilmInk.secondaryText)
    /// Firsts.
    public static let legendary = Color(rgb: DSFilmInk.legendary)
    /// Bosses and their badges.
    public static let boss = Color(rgb: DSFilmInk.boss)
    /// Darkens a photo under a card's words, enough to keep them readable on any photo.
    public static let scrim = Color(rgb: DSFilmInk.scrim).opacity(DSFilmInk.scrimOpacity)
    /// A soft edge behind words on a photo.
    public static let shadow = Color(rgb: DSFilmInk.scrim).opacity(0.5)

    // MARK: Type, from the frame's shorter side in pixels

    public static func title(_ shortSide: CGFloat) -> Font {
        .system(size: shortSide * 0.085, weight: .bold, design: .rounded)
    }

    public static func headline(_ shortSide: CGFloat) -> Font {
        .system(size: shortSide * 0.052, weight: .semibold, design: .rounded)
    }

    public static func body(_ shortSide: CGFloat) -> Font {
        .system(size: shortSide * 0.043)
    }

    public static func caption(_ shortSide: CGFloat) -> Font {
        .system(size: shortSide * 0.034, weight: .medium)
    }

    /// An emoji or a symbol used as the card's picture.
    public static func emoji(_ shortSide: CGFloat) -> Font {
        .system(size: shortSide * 0.16)
    }

    // MARK: Layout

    /// The film's unit of space; cards use whole multiples of it.
    public static func spacing(_ shortSide: CGFloat) -> CGFloat {
        shortSide * 0.02
    }

    /// What a card keeps clear around its words. A vertical film leaves room for what social apps draw over its top
    /// and bottom; a wide one is only kept off the edges.
    public static func margins(width: CGFloat, height: CGFloat) -> EdgeInsets {
        if height > width {
            EdgeInsets(top: height * 0.12, leading: width * 0.07, bottom: height * 0.18, trailing: width * 0.07)
        } else {
            EdgeInsets(top: height * 0.06, leading: width * 0.06, bottom: height * 0.06, trailing: width * 0.06)
        }
    }
}

/// The film's colours as numbers, so tests can measure them: every text colour reaches 4.5:1 on the ground, and the
/// text reaches it on the scrim over a white photo (`DSFilmContrastTests`).
///
/// The film is put together with Core Image, which mixes light, not sRGB values: a scrim of opacity `a` lets
/// `1 − a` of a photo's light through. That is brighter than the same opacity looks on a screen, so the scrim is
/// stronger than a screen's would be.
package enum DSFilmInk {
    package static let ground: UInt32 = 0x14131C
    package static let text: UInt32 = 0xFFFFFF
    package static let secondaryText: UInt32 = 0xB9B7C6
    package static let legendary: UInt32 = 0xFBBF24
    package static let boss: UInt32 = 0xFB923C
    package static let scrim: UInt32 = 0x000000
    package static let scrimOpacity = 0.84
}

private extension Color {
    /// A fixed colour from a 0xRRGGBB value: the same in light and dark mode.
    init(rgb: UInt32) {
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
