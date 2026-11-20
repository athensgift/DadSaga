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

    @Test("Given the iPhone Duo open flat on its side, when home is laid out, then it is two columns")
    func openFlatOnItsSide() {
        #expect(HomeArrangement.make(width: 951, fold: nil, flatFold: nil) == .columns)
    }

    @Test("Given the iPhone Duo open flat and upright, when home is laid out, then the hero is above where it folds")
    func openFlatUpright() {
        let flatFold = HorizontalFold(top: 440, bottom: 440)
        #expect(HomeArrangement.make(width: 669, fold: nil, flatFold: flatFold) == .stacked(flatFold))
    }

    @Test("Given a wide iPhone with no fold, when home is laid out, then it is two columns")
    func wideWithoutAFold() {
        #expect(HomeArrangement.make(width: 874, fold: nil) == .columns)
    }

    @Test("Given a narrow window over a flat fold, when home is laid out, then it stays one column")
    func narrowOverAFlatFold() {
        let flatFold = HorizontalFold(top: 440, bottom: 440)
        #expect(HomeArrangement.make(width: 330, fold: nil, flatFold: flatFold) == .column)
    }

    @Test("Given the iPhone Duo half-open, when home is laid out, then the gap of the fold wins over its flat place")
    func halfOpenWinsOverFlat() {
        let fold = HorizontalFold(top: 430, bottom: 460)
        let flatFold = HorizontalFold(top: 445, bottom: 445)
        #expect(HomeArrangement.make(width: 669, fold: fold, flatFold: flatFold) == .stacked(fold))
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
