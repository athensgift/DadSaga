import CoreGraphics
import FilmKit
import FilmTestSupport
import Foundation
import Testing

extension FilmKitTests {
    /// The closest camera that keeps a part of a photo whole (ADR-0044 §3).
    @Suite("Focus")
    struct FocusTests {
        let wide = FilmSpec(width: 1920, height: 1080)
        let square = CGSize(width: 1000, height: 1000)

        @Test("Given a small focus, when finding the closest camera, then it zooms no further than the limit, on it")
        func smallFocusCapped() {
            let focus = FilmRegion(left: 0.4, top: 0.3, width: 0.1, height: 0.1)

            let camera = FilmCamera.closest(on: focus, pictureSize: square, spec: wide, fit: .fitOverBlur, maxZoom: 1.25)

            // The square photo is narrower than the wide frame: it stays in the middle across. Down, the camera goes
            // as high as it can without the photo's top edge coming into the frame.
            #expect(camera.zoom == 1.25)
            #expect(camera.centerX == 0.5 && abs(camera.centerY - 0.4) < 1e-9)
        }

        @Test("Given a focus taller than the close-up shows, when finding the camera, then the zoom is lowered to fit it")
        func largeFocusLowersZoom() {
            // A wide photo fills the wide frame's width; the frame shows all of its height at zoom 1.
            let photo = CGSize(width: 2000, height: 1000)
            let focus = FilmRegion(left: 0.3, top: 0.02, width: 0.2, height: 0.95)

            let camera = FilmCamera.closest(on: focus, pictureSize: photo, spec: wide, fit: .fitOverBlur, maxZoom: 1.25)
            let seenDown = 1080.0 / (1000 * 0.96) / camera.zoom

            #expect(camera.zoom > 1 && camera.zoom < 1.25)
            #expect(camera.centerY - seenDown / 2 <= focus.top + 1e-9)
            #expect(camera.centerY + seenDown / 2 >= focus.top + focus.height - 1e-9)
        }

        @Test("Given a focus at the photo's edge, when finding the camera, then the edge stays out of the frame")
        func edgeStaysOut() {
            // A wide photo in a wide frame fills both sides once zoomed in.
            let photo = CGSize(width: 1920, height: 1080)
            let focus = FilmRegion(left: 0.9, top: 0.9, width: 0.08, height: 0.08)

            let camera = FilmCamera.closest(on: focus, pictureSize: photo, spec: wide, fit: .fitOverBlur, maxZoom: 1.25)
            let half = 1 / camera.zoom / 2

            #expect(camera.zoom == 1.25)
            #expect(abs(camera.centerX - (1 - half)) < 1e-9 && abs(camera.centerY - (1 - half)) < 1e-9)
            #expect(camera.centerX + half >= focus.left + focus.width)
        }

        @Test("Given a tall photo in a wide frame, when finding the camera, then its sides stay in the frame")
        func narrowSideStaysWhole() {
            let tall = CGSize(width: 600, height: 1200)
            let focus = FilmRegion(left: 0.05, top: 0.2, width: 0.1, height: 0.1)

            let camera = FilmCamera.closest(on: focus, pictureSize: tall, spec: wide, fit: .fitOverBlur, maxZoom: 1.25)

            // The photo is half as wide as the frame shows across, even zoomed in: it stays in the middle across.
            #expect(camera.centerX == 0.5)
            #expect(abs(camera.centerY - 0.4) < 1e-9)
        }

        @Test("Given a photo whose loader brings its own motion, when encoding, then the clip moves by it")
        func photoMotionReplacesTheClips() async throws {
            let gradient = try Fixture.image(width: 400, height: 400) { column, _ in
                Fixture.Paint(red: UInt8(column * 255 / 399), blue: UInt8(255 - column * 255 / 399))
            }
            let glide = FilmMotion.kenBurns(
                start: FilmCamera(zoom: 1.5, centerX: 0.3), end: FilmCamera(zoom: 1.5, centerX: 0.7)
            )
            let clip = FilmClip(frames: 30, picture: .image { FilmPhoto(gradient, motion: glide) })
            let url = try await Fixture.encode(FilmTimeline(spec: Fixture.landscape, clips: [clip]))
            defer { try? FileManager.default.removeItem(at: url) }

            let first = try await FilmProbe.pixel(url, at: 0.5 / 30)
            let last = try await FilmProbe.pixel(url, at: 29.5 / 30)

            #expect(last.red > first.red + 60, "\(first) → \(last)")
        }
    }
}
