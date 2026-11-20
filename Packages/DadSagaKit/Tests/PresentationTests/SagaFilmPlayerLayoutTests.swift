import CoreGraphics
import DesignSystem
@testable import Presentation
import Testing

@Suite("Saga film player layout")
struct SagaFilmPlayerLayoutTests {
    private let wide = 16.0 / 9.0
    private let vertical = 9.0 / 16.0
    /// The film sheet on an iPhone Duo open in portrait, and the fold across it when half-open.
    private let sheet = CGSize(width: 669, height: 800)
    private let fold = HorizontalFold(top: 420, bottom: 450)

    @Test("Given a wide film on a half-open iPhone Duo, when it is sized, then it fills the width and stays above the fold")
    func wideFilmAboveTheFold() {
        let size = SagaFilmPlayer.filmSize(aspectRatio: wide, in: sheet, fold: fold)
        #expect(size.width == sheet.width - 2 * DSSpacing.m)
        #expect(size.height <= fold.top - 2 * DSSpacing.m)
        #expect(abs(size.width / size.height - wide) < 0.001)
    }

    @Test("Given a vertical film on a half-open iPhone Duo, when it is sized, then it is as tall as the room above the fold")
    func verticalFilmAboveTheFold() {
        let size = SagaFilmPlayer.filmSize(aspectRatio: vertical, in: sheet, fold: fold)
        #expect(abs(size.height - (fold.top - 2 * DSSpacing.m)) < 0.001)
        #expect(abs(size.width / size.height - vertical) < 0.001)
    }

    @Test("Given a vertical film on an iPhone, when it is sized, then it leaves room for sharing under it")
    func verticalFilmFlat() {
        let phone = CGSize(width: 402, height: 760)
        let size = SagaFilmPlayer.filmSize(aspectRatio: vertical, in: phone, fold: nil)
        #expect(abs(size.height - phone.height * 0.58) < 0.001)
        #expect(abs(size.width / size.height - vertical) < 0.001)
    }

    @Test("Given a wide film on a wide flat sheet, when it is sized, then it is no wider than a readable column")
    func wideFilmFlat() {
        let size = SagaFilmPlayer.filmSize(aspectRatio: wide, in: sheet, fold: nil)
        #expect(size.width == 560)
    }

    @Test("Given a sheet not laid out yet, when the film is sized, then it has no size rather than a negative one")
    func beforeLayout() {
        #expect(SagaFilmPlayer.filmSize(aspectRatio: wide, in: .zero, fold: nil) == .zero)
    }
}
