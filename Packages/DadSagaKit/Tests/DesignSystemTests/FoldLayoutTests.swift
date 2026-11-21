import CoreGraphics
import DesignSystem
import Testing

@Suite("Fold layout")
struct FoldLayoutTests {
    private let screen = CGSize(width: 669, height: 880)

    private func fold(_ divisions: [CGRect], in size: CGSize? = nil, below: CGFloat = 200) -> HorizontalFold? {
        HorizontalFold.across(size ?? screen, divisions: divisions, minimumAbove: 200, minimumBelow: below)
    }

    @Test("Given a flat display, when the view looks for a fold, then there is none")
    func flatDisplay() {
        #expect(fold([]) == nil)
    }

    @Test("Given a fold across the middle, when the view looks for it, then one pane ends and the other starts at it")
    func foldAcrossTheMiddle() {
        let found = fold([CGRect(x: 0, y: 420, width: 669, height: 40)])
        #expect(found == HorizontalFold(top: 420, bottom: 460))
    }

    @Test("Given a fold running down the view, like a book, when the view looks for a fold across it, then there is none")
    func foldDownTheView() {
        #expect(fold([CGRect(x: 455, y: 0, width: 40, height: 669)], in: CGSize(width: 951, height: 669)) == nil)
    }

    @Test("Given a flat display on its side, where the fold runs down with no thickness, when the view looks, then there is none")
    func flatFoldDownTheView() {
        #expect(fold([CGRect(x: 475, y: 0, width: 0, height: 669)], in: CGSize(width: 951, height: 669)) == nil)
    }

    @Test("Given a fold reported wider than the sheet it crosses, when the sheet looks for it, then it still folds the sheet")
    func foldWiderThanTheView() {
        let found = fold([CGRect(x: -20, y: 380, width: 709, height: 30)], in: CGSize(width: 629, height: 800))
        #expect(found == HorizontalFold(top: 380, bottom: 410))
    }

    @Test("Given the keyboard leaves little room below the fold, when the view looks for a fold, then there is none")
    func noRoomBelow() {
        #expect(fold([CGRect(x: 0, y: 420, width: 669, height: 40)], in: CGSize(width: 669, height: 500)) == nil)
    }

    @Test("Given a short sheet that starts just above the fold, when it looks for a fold, then there is none")
    func noRoomAbove() {
        #expect(fold([CGRect(x: 0, y: 90, width: 669, height: 40)]) == nil)
    }

    @Test("Given a pane below that needs little room, when the keyboard leaves that much, then the view still folds")
    func littleRoomNeededBelow() {
        let found = fold([CGRect(x: 0, y: 420, width: 669, height: 40)], in: CGSize(width: 669, height: 600), below: 120)
        #expect(found == HorizontalFold(top: 420, bottom: 460))
    }

    @Test("Given a fold with no thickness, when the view looks for it, then both panes meet at it")
    func foldWithNoThickness() {
        #expect(fold([CGRect(x: 0, y: 440, width: 669, height: 0)]) == HorizontalFold(top: 440, bottom: 440))
    }

    @Test("Given the iPhone Duo open flat and upright, when home looks for its fold, then the panes meet at the hinge's middle")
    func flatFoldHasNoThickness() {
        let hinge = CGRect(x: 0, y: 420, width: 669, height: 40)
        let divisions = HorizontalFold.divisions(active: [], all: [hinge], whileFlat: true)
        #expect(fold(divisions) == HorizontalFold(top: 440, bottom: 440))
    }

    @Test("Given the iPhone Duo half-open, when home looks for where it folds, then the hinge's whole gap is kept clear")
    func halfOpenFoldKeepsItsGap() {
        let hinge = CGRect(x: 0, y: 420, width: 669, height: 40)
        let divisions = HorizontalFold.divisions(active: [hinge], all: [hinge], whileFlat: true)
        #expect(fold(divisions) == HorizontalFold(top: 420, bottom: 460))
    }

    @Test("Given the iPhone Duo open flat on its side, when home looks for a fold across it, then there is none")
    func flatFoldDownTheViewStaysDown() {
        let hinge = CGRect(x: 455, y: 0, width: 40, height: 669)
        let divisions = HorizontalFold.divisions(active: [], all: [hinge], whileFlat: true)
        #expect(fold(divisions, in: CGSize(width: 951, height: 669)) == nil)
    }

    @Test("Given a screen that splits only while half-open, when the device lies flat, then there is no fold")
    func flatWithoutAskingForIt() {
        let hinge = CGRect(x: 0, y: 420, width: 669, height: 40)
        #expect(HorizontalFold.divisions(active: [], all: [hinge], whileFlat: false).isEmpty)
    }

    @Test("Given a fold that stops short of the view's edge, when the view looks for a fold across it, then there is none")
    func foldNotSpanningTheWidth() {
        #expect(fold([CGRect(x: 0, y: 420, width: 400, height: 40)]) == nil)
    }

    @Test("Given a fold outside the view, when the view looks for a fold, then there is none")
    func foldOutsideTheView() {
        #expect(fold([CGRect(x: 0, y: 1_000, width: 669, height: 40)]) == nil)
    }

    @Test("Given a fold, when the two panes are placed, then they fill the width above and below it and leave it empty")
    func paneFrames() {
        let panes = FoldedStackLayout.paneFrames(in: screen, fold: HorizontalFold(top: 400, bottom: 440))
        #expect(panes.top == CGRect(x: 0, y: 0, width: 669, height: 400))
        #expect(panes.bottom == CGRect(x: 0, y: 440, width: 669, height: 440))
    }
}
