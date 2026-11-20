import CoreGraphics
import DesignSystem
import Testing

@Suite("Fold layout")
struct FoldLayoutTests {
    private let screen = CGSize(width: 669, height: 880)

    private func fold(_ divisions: [CGRect], in size: CGSize? = nil, minimum: CGFloat = 200) -> HorizontalFold? {
        HorizontalFold.across(size ?? screen, divisions: divisions, minimumPaneHeight: minimum)
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
