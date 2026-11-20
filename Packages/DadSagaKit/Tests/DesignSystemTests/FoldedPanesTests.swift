import CoreGraphics
import DesignSystem
import Testing

@Suite("Folded panes")
struct FoldedPanesTests {
    private let fold = HorizontalFold(top: 380, bottom: 410)
    private let sheet = CGSize(width: 669, height: 800)

    private func geometry(_ fold: HorizontalFold?, height: CGFloat = 800, width: CGFloat = 669) -> FoldGeometry {
        FoldGeometry(fold: fold, size: CGSize(width: width, height: height))
    }

    @Test("Given a flat sheet, when the device folds, then the sheet splits at the fold")
    func folds() {
        #expect(FoldedPanes.flat.next(geometry(fold), sizeWhenSplit: .zero) == .split(fold))
    }

    @Test("Given a split sheet, when the keyboard takes the lower half, then the lower part alone stays")
    func keyboardComesUp() {
        #expect(FoldedPanes.split(fold).next(geometry(nil, height: 420), sizeWhenSplit: sheet) == .lowerOnly)
    }

    @Test("Given the keyboard over the lower half, when it goes, then the sheet is split again")
    func keyboardGoes() {
        #expect(FoldedPanes.lowerOnly.next(geometry(fold), sizeWhenSplit: sheet) == .split(fold))
    }

    @Test("Given a split sheet, when the device is opened flat, then the sheet is one column")
    func opensFlat() {
        #expect(FoldedPanes.split(fold).next(geometry(nil), sizeWhenSplit: sheet) == .flat)
    }

    @Test("Given a split sheet, when the device is turned on its side, then the sheet is one column, not half of one")
    func turned() {
        let onItsSide = geometry(nil, height: 560, width: 951)
        #expect(FoldedPanes.split(fold).next(onItsSide, sizeWhenSplit: sheet) == .flat)
    }

    @Test("Given the device opened flat while typing, when the keyboard goes, then the sheet is one column")
    func opensFlatWhileTyping() {
        #expect(FoldedPanes.lowerOnly.next(geometry(nil), sizeWhenSplit: sheet) == .flat)
    }

    @Test("Given a flat sheet, when the keyboard comes up, then it stays one column")
    func keyboardOnAFlatSheet() {
        #expect(FoldedPanes.flat.next(geometry(nil, height: 420), sizeWhenSplit: .zero) == .flat)
    }
}
