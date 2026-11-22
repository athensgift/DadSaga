import CoreGraphics
import DesignSystem
@testable import Presentation
import Testing

@Suite("Home arrangement")
struct HomeArrangementTests {
    @Test("Given an iPhone in portrait, when home is laid out, then it is one column")
    func phone() {
        #expect(HomeArrangement.make(width: 390, fold: nil, flatFold: nil) == .column)
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
        #expect(HomeArrangement.make(width: 874, fold: nil, flatFold: nil) == .columns)
    }

    @Test("Given home exactly as wide as two columns need, over a flat fold, when it is laid out, then it is split there")
    func justWideEnough() {
        let flatFold = HorizontalFold(top: 440, bottom: 440)
        #expect(HomeArrangement.make(width: 600, fold: nil, flatFold: flatFold) == .stacked(flatFold))
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
        #expect(HomeArrangement.make(width: 669, fold: fold, flatFold: nil) == .stacked(fold))
        #expect(HomeArrangement.make(width: 330, fold: fold, flatFold: nil) == .stacked(fold))
        #expect(HomeArrangement.stacked(fold).hasPanes)
    }

    @Test("Given a tall pane above the fold, when the hero is sized, then he is as big as in the two columns")
    func heroInATallPane() {
        let tall = HomeArrangement.stacked(HorizontalFold(top: 520, bottom: 550))
        let columns = HomeArrangement.columns.maxHeroSize(headerHeight: 41, besideTitle: false)
        #expect(tall.maxHeroSize(headerHeight: 41, besideTitle: true) == columns)
    }

    @Test("Given the iPhone Duo open upright, when the hero is sized, then he fills what the title leaves above the fold")
    func heroReachesTheFold() {
        let open = HomeArrangement.stacked(HorizontalFold(top: 393.5, bottom: 393.5))
        #expect(open.maxHeroSize(headerHeight: 41, besideTitle: true) == 256.5)
        #expect(open.maxHeroSize(headerHeight: 69, besideTitle: true) == 228.5)
    }

    @Test("Given the accessibility text sizes, when the hero is sized above a fold, then he is no taller than in one column")
    func heroOverHisLevel() {
        let open = HomeArrangement.stacked(HorizontalFold(top: 520, bottom: 520))
        let column = HomeArrangement.column.maxHeroSize(headerHeight: 0, besideTitle: false)
        #expect(open.maxHeroSize(headerHeight: 41, besideTitle: false) == column)
    }

    @Test("Given a short pane above the fold, when the hero is sized, then he shrinks but stays recognisable")
    func heroInAShortPane() {
        let short = HomeArrangement.stacked(HorizontalFold(top: 210, bottom: 240))
        #expect(short.maxHeroSize(headerHeight: 41, besideTitle: true) == 120)
    }
}
