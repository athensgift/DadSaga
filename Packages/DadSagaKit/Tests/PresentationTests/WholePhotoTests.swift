@testable import Presentation
import Testing

@Suite("Whole photo")
struct WholePhotoTests {
    @Test("Given photos of every shape, when framed, then the frame stays between 4:5 and 16:9", arguments: [
        (0.33, 0.8), (0.75, 0.8), (1.0, 1.0), (1.5, 1.5), (3.2, 16.0 / 9.0)
    ])
    func clampsShape(aspectRatio: Double, expected: Double) {
        #expect(abs(WholePhoto.frameRatio(for: aspectRatio) - expected) < 0.0001)
    }

    @Test("Given a photo still loading, when framed, then the frame is 4:3")
    func loading() {
        let ratio: Double = WholePhoto.frameRatio(for: nil)
        #expect(abs(ratio - 4.0 / 3.0) < 0.0001, "\(ratio)")
    }
}
