import CoreGraphics
import FilmKit
import Foundation
import Synchronization
import Testing

extension FilmKitTests {
    @Suite("Loading")
    struct LoadingTests {
        let encoder = FilmEncoder()

        @Test("Given photo clips with cards, when encoding, then each clip's images load while the clip before it is written")
        func imagesLoadOneClipAhead() async throws {
            let written = Mutex(0)
            let loads = Mutex<[String: [Int]]>([:])
            let photo = try Fixture.image(width: 40, height: 40) { _, _ in .grey }
            let card = try Fixture.image(width: 180, height: 320) { _, _ in .clear }
            @Sendable func noting(_ name: String, _ image: CGImage) -> FilmImageLoader {
                {
                    loads.withLock { $0[name, default: []].append(written.withLock { $0 }) }
                    return image
                }
            }
            let clips = (0..<4).map { index in
                FilmClip(
                    frames: 10,
                    picture: .image { [load = noting("photo \(index)", photo)] in FilmPhoto(try await load()) },
                    overlay: noting("card \(index)", card)
                )
            }
            let url = Fixture.temporaryURL()
            try await encoder.encode(FilmTimeline(spec: Fixture.portrait, clips: clips), to: url) { _ in
                let count = written.withLock { count in
                    count += 1
                    return count
                }
                // Holds each clip's first frame until the next clip's images are asked for, so the frame counts below
                // don't hang on timing. Without loading ahead nobody asks, and it gives up after two seconds.
                let next = count / 10 + 1
                guard count % 10 == 1, next < clips.count else { return }
                let deadline = ContinuousClock.now + .seconds(2)
                func asked() -> Bool {
                    loads.withLock { $0["photo \(next)"] != nil && $0["card \(next)"] != nil }
                }
                while !asked(), ContinuousClock.now < deadline {
                    Thread.sleep(forTimeInterval: 0.001)
                }
            }
            defer { try? FileManager.default.removeItem(at: url) }

            let seen = loads.withLock { $0 }
            #expect(seen.count == 8)
            for index in 0..<4 {
                // Asked for once: not before the clip before it starts, and before that clip's second frame is done.
                let start = max(0, (index - 1) * 10)
                let window = start...(index == 0 ? 0 : start + 1)
                for name in ["photo \(index)", "card \(index)"] {
                    let frames = seen[name] ?? []
                    #expect(frames.count == 1 && frames.allSatisfy(window.contains), "\(name) asked for at \(frames)")
                }
            }
        }

        @Test("Given many cross-fading photo clips with cards, when encoding, then two clips' images at most are in memory")
        func twoClipsInMemoryAtMost() async throws {
            let ledger = ImageLedger()
            let clips = (0..<8).map { index in
                FilmClip(
                    frames: 12,
                    picture: .image { FilmPhoto(try ledger.image(width: 64, height: 64)) },
                    overlay: { try ledger.image(width: 180, height: 320) },
                    transitionIn: index == 0 ? .cut : .crossfade(frames: 6)
                )
            }
            let url = try await Fixture.encode(FilmTimeline(spec: Fixture.portrait, clips: clips))
            defer { try? FileManager.default.removeItem(at: url) }

            // Each clip has a photo and a card.
            #expect(ledger.most <= 4, "\(ledger.most) images at once")
            #expect(ledger.alive == 0, "\(ledger.alive) images left")
        }
    }
}
