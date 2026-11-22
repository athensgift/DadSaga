import CoreGraphics
import DesignSystem
@testable import Presentation
import Testing

@Suite("Home arrangement")
struct HomeArrangementTests {
    @Test("Given an iPhone in portrait, when home is laid out, then it is one column, with the bar")
    func phone() {
        #expect(HomeArrangement.make(width: 390, fold: nil) == .column)
        #expect(!HomeArrangement.column.hasPanes)
    }

    @Test("Given the iPhone Duo open flat on its side, when home is laid out, then it is two columns")
    func openFlatOnItsSide() {
        #expect(HomeArrangement.make(width: 951, fold: nil) == .columns)
    }

    @Test("Given the iPhone Duo open flat and upright, when home is laid out, then the hero is above the hinge")
    func openFlatUpright() {
        let line = HorizontalFold(top: 440, bottom: 440)
        #expect(HomeArrangement.make(width: 669, fold: nil, flatFold: line) == .stacked(line))
        #expect(HomeArrangement.stacked(line).hasPanes)
    }

    @Test("Given a narrow window over the flat Duo's fold, when home is laid out, then it stays one column")
    func narrowOverTheFlatFold() {
        let line = HorizontalFold(top: 440, bottom: 440)
        #expect(HomeArrangement.make(width: 330, fold: nil, flatFold: line) == .column)
    }

    @Test("Given home exactly as wide as two columns need, when it is laid out, then it is two columns; narrower, one")
    func justWideEnough() {
        #expect(HomeArrangement.make(width: 600, fold: nil) == .columns)
        #expect(HomeArrangement.make(width: 599, fold: nil) == .column)
    }

    @Test("Given a fold across home, when it is laid out, then the hero is above it and the adventure below, also when narrow")
    func folded() {
        let fold = HorizontalFold(top: 430, bottom: 460)
        #expect(HomeArrangement.make(width: 669, fold: fold) == .stacked(fold))
        #expect(HomeArrangement.make(width: 330, fold: fold) == .stacked(fold))
        #expect(HomeArrangement.stacked(fold).hasPanes)
    }

    @Test("Given the upright iPhone Duo, when it folds and opens again, then the rows stay and only the gap at the hinge changes")
    func foldingKeepsTheRows() {
        let flat = HorizontalFold(top: 440, bottom: 440)
        let halfOpen = HorizontalFold(top: 420, bottom: 460)
        #expect(HomeArrangement.make(width: 669, fold: nil, flatFold: flat) == .stacked(flat))
        #expect(HomeArrangement.make(width: 669, fold: halfOpen, flatFold: flat) == .stacked(halfOpen))
        #expect(HomeArrangement.make(width: 669, fold: nil, flatFold: flat) == .stacked(flat))
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

    @Test("Given two columns, when the hero is sized, then he yields what stands under him so the pane fits, down to 120")
    func heroYieldsInColumns() {
        let columns = HomeArrangement.columns
        // 611 pt of pane, a 41 pt title and 250 pt under him: 611 − 41 − 250 − 96 − 16.
        #expect(columns.maxHeroSize(headerHeight: 41, besideTitle: false, under: 250, paneHeight: 611) == 208)
        #expect(columns.maxHeroSize(headerHeight: 41, besideTitle: false, under: 100, paneHeight: 611) == 260)
        #expect(columns.maxHeroSize(headerHeight: 41, besideTitle: false, under: 400, paneHeight: 611) == 120)
        // Until the pane's height is known he is drawn at his widest.
        #expect(columns.maxHeroSize(headerHeight: 41, besideTitle: false, under: 250) == 260)
    }
}
