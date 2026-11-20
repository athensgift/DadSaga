@testable import DesignSystem
import SwiftUI
import Testing

/// ADR-0037 §2: a film card's words are readable on its dark ground and over any photo.
@Suite("Film card contrast")
struct DSFilmContrastTests {
    @Test("Given each of the film's text colours, when it is on the card's ground, then it reaches AA")
    func textOnGround() {
        for color in [DSFilmInk.text, DSFilmInk.secondaryText, DSFilmInk.legendary, DSFilmInk.boss] {
            #expect(WCAG.contrast(color, DSFilmInk.ground) >= WCAG.smallText, "\(hex(color)) on the ground")
        }
    }

    @Test("Given a white photo, when the scrim darkens it under the words, then the film's white text reaches AA")
    func textOverTheBrightestPhoto() {
        // The film mixes light (Core Image): a black scrim leaves a white photo `1 − opacity` of its luminance, and
        // white text has a luminance of 1. The renderer's tests measure the same thing in a written film.
        #expect(DSFilmInk.scrim == 0x000000 && DSFilmInk.text == 0xFFFFFF)
        let photo = 1 - DSFilmInk.scrimOpacity
        #expect((1 + 0.05) / (photo + 0.05) >= WCAG.smallText)
    }

    @Test("Given a vertical film, when laying out a card, then its bottom keeps the most room clear and its sides the least")
    func verticalMargins() {
        let margins = DSFilm.margins(width: 1080, height: 1920)
        #expect(margins.top >= 1920 * 0.1)
        #expect(margins.bottom > margins.top)
        #expect(margins.leading == margins.trailing)
        #expect(margins.leading < margins.top)
    }

    @Test("Given a wide film, when laying out a card, then it keeps the same share of each side clear")
    func wideMargins() {
        let margins = DSFilm.margins(width: 1920, height: 1080)
        #expect(margins.top == margins.bottom)
        #expect(margins.leading == margins.trailing)
        #expect(abs(margins.top / 1080 - margins.leading / 1920) < 0.000_1)
    }
}
