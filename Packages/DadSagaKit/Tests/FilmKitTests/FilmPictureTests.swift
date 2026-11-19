import FilmKit
import Foundation
import Testing

extension FilmKitTests {
    @Suite("Pictures")
    struct PictureTests {
        let encoder = FilmEncoder()

        @Test("Given red, green and blue clips, when encoding, then each second shows its own colour")
        func coloursInOrder() async throws {
            let url = try await Fixture.encode(Fixture.solidFilm([Fixture.red, Fixture.green, Fixture.blue]))
            defer { try? FileManager.default.removeItem(at: url) }

            let red = try await FilmProbe.pixel(url, at: 0.5)
            let green = try await FilmProbe.pixel(url, at: 1.5)
            let blue = try await FilmProbe.pixel(url, at: 2.5)

            #expect(red.red > 200 && red.green < 50 && red.blue < 50)
            #expect(green.green > 200 && green.red < 50 && green.blue < 50)
            #expect(blue.blue > 200 && blue.red < 50 && blue.green < 50)
        }

        @Test("Given a mid-grey colour and a mid-grey photo, when encoding, then both play back as the same mid-grey")
        func tonesSurvive() async throws {
            let photo = try Fixture.image(width: 180, height: 320) { _, _ in Fixture.Paint(red: 128, green: 128, blue: 128) }
            let grey = FilmColor(red: 128.0 / 255, green: 128.0 / 255, blue: 128.0 / 255)
            let clips = [FilmClip(frames: 15, picture: .solid(grey)), FilmClip(frames: 15, picture: .image { photo })]
            let url = try await Fixture.encode(FilmTimeline(spec: Fixture.portrait, clips: clips))
            defer { try? FileManager.default.removeItem(at: url) }

            for seconds in [0.25, 0.75] {
                let pixel = try await FilmProbe.pixel(url, at: seconds)
                #expect([pixel.red, pixel.green, pixel.blue].allSatisfy { abs($0 - 128) < 6 }, "\(pixel) at \(seconds) s")
            }
        }

        @Test("Given a cross-fade from red to blue, when encoding, then its midpoint is an even mix of both")
        func crossfadeMidpoint() async throws {
            let clips = Fixture.solids([Fixture.red, Fixture.blue], transition: .crossfade(frames: 29))
            let url = try await Fixture.encode(FilmTimeline(spec: Fixture.portrait, clips: clips))
            defer { try? FileManager.default.removeItem(at: url) }

            let middle = try await FilmProbe.pixel(url, at: 44.5 / 30)
            let end = try await FilmProbe.pixel(url, at: 59.5 / 30)

            #expect(abs(middle.red - middle.blue) < 30, "\(middle)")
            #expect(middle.red > 80 && middle.blue > 80 && middle.green < 50, "\(middle)")
            #expect(end.blue > 200 && end.red < 50, "\(end)")
        }

        @Test("Given a cross-fade longer than its clip, when encoding, then the clip still ends as itself")
        func crossfadeLongerThanItsClip() async throws {
            let clips = [
                FilmClip(frames: 30, picture: .solid(Fixture.red)),
                FilmClip(frames: 10, picture: .solid(Fixture.blue), transitionIn: .crossfade(frames: 30))
            ]
            let url = try await Fixture.encode(FilmTimeline(spec: Fixture.portrait, clips: clips))
            defer { try? FileManager.default.removeItem(at: url) }

            let first = try await FilmProbe.pixel(url, at: 30.5 / 30)
            let last = try await FilmProbe.pixel(url, at: 39.5 / 30)

            #expect(try await FilmProbe.frameCount(url) == 40)
            #expect(first.red > first.blue, "\(first)")
            #expect(last.blue > 200 && last.red < 50, "\(last)")
        }

        @Test("Given a cross-fade on the first clip, when encoding, then the film opens on that clip alone")
        func crossfadeWithNothingBefore() async throws {
            let clips = [FilmClip(frames: 10, picture: .solid(Fixture.green), transitionIn: .crossfade(frames: 5))]
            let url = try await Fixture.encode(FilmTimeline(spec: Fixture.portrait, clips: clips))
            defer { try? FileManager.default.removeItem(at: url) }

            let first = try await FilmProbe.pixel(url, at: 0.5 / 30)

            #expect(first.green > 200 && first.red < 50 && first.blue < 50, "\(first)")
        }

        @Test("Given a centred white card over green, when encoding, then the centre is white and a corner green")
        func overlayOnTop() async throws {
            let card = try Fixture.image(width: 180, height: 320) { column, row in
                (60..<120).contains(column) && (120..<200).contains(row) ? .white : .clear
            }
            let clip = FilmClip(frames: 15, picture: .solid(Fixture.green), overlay: { card })
            let url = try await Fixture.encode(FilmTimeline(spec: Fixture.portrait, clips: [clip]))
            defer { try? FileManager.default.removeItem(at: url) }

            let centre = try await FilmProbe.pixel(url, at: 0.2)
            let corner = try await FilmProbe.pixel(url, at: 0.2, across: 0.05, down: 0.05)

            #expect(centre.red > 220 && centre.green > 220 && centre.blue > 220)
            #expect(corner.green > 200 && corner.red < 50)
        }

        @Test("Given a square card in a tall film, when encoding, then it fits the width, centred, and is not stretched")
        func overlayOfAnotherShape() async throws {
            let card = try Fixture.image(width: 90, height: 90) { _, _ in .white }
            let clip = FilmClip(frames: 15, picture: .solid(Fixture.green), overlay: { card })
            let url = try await Fixture.encode(FilmTimeline(spec: Fixture.portrait, clips: [clip]))
            defer { try? FileManager.default.removeItem(at: url) }

            // The card is drawn 180 × 180, so it covers rows 70 to 250 of 320.
            let centre = try await FilmProbe.pixel(url, at: 0.2)
            let leftEdge = try await FilmProbe.pixel(url, at: 0.2, across: 0.03)
            let above = try await FilmProbe.pixel(url, at: 0.2, down: 0.15)
            let below = try await FilmProbe.pixel(url, at: 0.2, down: 0.85)

            #expect(centre.red > 220 && centre.blue > 220, "\(centre)")
            #expect(leftEdge.red > 220 && leftEdge.blue > 220, "\(leftEdge)")
            #expect(above.green > 200 && above.red < 50, "\(above)")
            #expect(below.green > 200 && below.red < 50, "\(below)")
        }

        @Test(
            "Given a gradient that reddens along one axis, when the camera glides along it, then the centre reddens",
            arguments: [true, false]
        )
        func kenBurnsFollowsItsCamera(horizontal: Bool) async throws {
            let gradient = try Fixture.image(width: 400, height: 400) { column, row in
                let along = UInt8((horizontal ? column : row) * 255 / 399)
                return Fixture.Paint(red: along, blue: 255 - along)
            }
            let glide = horizontal
                ? FilmMotion.kenBurns(start: FilmCamera(zoom: 1.5, centerX: 0.3), end: FilmCamera(zoom: 1.5, centerX: 0.7))
                : FilmMotion.kenBurns(start: FilmCamera(zoom: 1.5, centerY: 0.3), end: FilmCamera(zoom: 1.5, centerY: 0.7))
            let clip = FilmClip(frames: 30, picture: .image { gradient }, motion: glide)
            let url = try await Fixture.encode(FilmTimeline(spec: Fixture.landscape, clips: [clip]))
            defer { try? FileManager.default.removeItem(at: url) }

            let first = try await FilmProbe.pixel(url, at: 0.5 / 30)
            let last = try await FilmProbe.pixel(url, at: 29.5 / 30)

            #expect(last.red > first.red + 60, "\(first) → \(last)")
            #expect(last.blue < first.blue - 60, "\(first) → \(last)")
            #expect(abs(first.red - 76) < 25 && abs(last.red - 178) < 25, "\(first) → \(last)")
        }

        @Test("Given a gradient photo and a camera that stays, when encoding, then the frames don't change")
        func stillPhotoStaysStill() async throws {
            let gradient = try Fixture.image(width: 400, height: 400) { column, _ in
                Fixture.Paint(red: UInt8(column * 255 / 399), blue: UInt8(255 - column * 255 / 399))
            }
            let clip = FilmClip(frames: 30, picture: .image { gradient })
            let url = try await Fixture.encode(FilmTimeline(spec: Fixture.landscape, clips: [clip]))
            defer { try? FileManager.default.removeItem(at: url) }

            let first = try await FilmProbe.pixel(url, at: 0.5 / 30)
            let last = try await FilmProbe.pixel(url, at: 29.5 / 30)

            #expect(abs(first.red - last.red) < 10 && abs(first.blue - last.blue) < 10, "\(first) → \(last)")
        }

        @Test("Given a tall photo fitted over its blur in a wide film, when encoding, then the sides show it blurred, not black")
        func fitOverBlur() async throws {
            let photo = try Fixture.image(width: 100, height: 300) { _, row in
                row < 150 ? Fixture.Paint(red: 255) : Fixture.Paint(blue: 255)
            }
            let clip = FilmClip(frames: 15, picture: .image { photo }, fit: .fitOverBlur)
            let url = try await Fixture.encode(FilmTimeline(spec: Fixture.landscape, clips: [clip]))
            defer { try? FileManager.default.removeItem(at: url) }

            // The photo is drawn 60 × 180 in the middle; red meets blue half-way down, in the photo and in its blur.
            let top = try await FilmProbe.pixel(url, at: 0.2, down: 0.25)
            let bottom = try await FilmProbe.pixel(url, at: 0.2, down: 0.75)
            let nearTheSeam = try await FilmProbe.pixel(url, at: 0.2, down: 0.44)
            let side = try await FilmProbe.pixel(url, at: 0.2, across: 0.1, down: 0.25)
            let sideNearTheSeam = try await FilmProbe.pixel(url, at: 0.2, across: 0.1, down: 0.44)

            #expect(top.red > 220 && top.blue < 40, "\(top)")
            #expect(bottom.blue > 220 && bottom.red < 40, "\(bottom)")
            #expect(nearTheSeam.red > 220 && nearTheSeam.blue < 40, "\(nearTheSeam)")
            #expect(side.red > 150 && side.red < top.red - 5 && side.blue < 40, "\(side) beside \(top)")
            #expect(sideNearTheSeam.red > 100 && sideNearTheSeam.blue > 60, "\(sideNearTheSeam)")
        }
    }
}
