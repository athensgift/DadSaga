import CoreGraphics
import DesignSystem
@testable import Presentation
import Testing

@Suite("Home arrangement")
struct HomeArrangementTests {
    @Test("Given an iPhone in portrait, when home is laid out, then it is one column")
    func phone() {
        #expect(HomeArrangement.make(width: 390, fold: nil) == .column)
        #expect(!HomeArrangement.column.hasPanes)
    }

    @Test("Given the iPhone Duo open flat, when home is laid out, then it is two columns in both orientations")
    func openFlat() {
        #expect(HomeArrangement.make(width: 669, fold: nil) == .columns)
        #expect(HomeArrangement.make(width: 951, fold: nil) == .columns)
    }

    @Test("Given a fold across home, when it is laid out, then the hero is above it and the adventure below, also when narrow")
    func folded() {
        let fold = HorizontalFold(top: 430, bottom: 460)
        #expect(HomeArrangement.make(width: 669, fold: fold) == .stacked(fold))
        #expect(HomeArrangement.make(width: 330, fold: fold) == .stacked(fold))
        #expect(HomeArrangement.stacked(fold).hasPanes)
    }

    @Test("Given a tall pane above the fold, when the hero is sized, then he is as big as in the two columns")
    func heroInATallPane() {
        let tall = HomeArrangement.stacked(HorizontalFold(top: 520, bottom: 550))
        #expect(tall.maxHeroSize == HomeArrangement.columns.maxHeroSize)
    }

    @Test("Given a short pane above the fold, when the hero is sized, then he shrinks but stays recognisable")
    func heroInAShortPane() {
        let short = HomeArrangement.stacked(HorizontalFold(top: 360, bottom: 390))
        #expect(short.maxHeroSize == 180)
        #expect(HomeArrangement.stacked(HorizontalFold(top: 210, bottom: 240)).maxHeroSize == 120)
    }
}
