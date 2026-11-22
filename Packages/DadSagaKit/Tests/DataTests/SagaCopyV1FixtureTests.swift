import Application
import CoreGraphics
import Domain
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Data

/// Every later version reads format 1 (ADR-0057 §4): the file in `Fixtures/SagaCopyV1` was written by the build that
/// introduced it.
@Suite("A copy in format 1")
struct SagaCopyV1FixtureTests {
    @Test("Given the format-1 copy, when reading it, then it is the saga it was made from, its photos byte for byte")
    func readsFormat1() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "dadsaga-copy-v1-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let photos = FilePhotoStore.moments(in: folder)
        let files = AppleArchiveSagaCopyFiles(folder: folder.appending(path: "tmp"))
        let adopted = AdoptedIDs()

        let copy = try await files.read(fileAt: SagaCopyV1Fixture.file, adopt: { data in
            let id = try await photos.adopt(data)
            await adopted.append(id)
            return id
        }, progress: { _ in })

        let ids = await adopted.ids
        #expect(copy == SagaCopy(
            saga: SagaCopyV1Fixture.copy.saga.replacingPhotoIDs(
                Dictionary(uniqueKeysWithValues: zip(SagaCopyV1Fixture.photoIDs, ids))
            ),
            answeredOccasionIDs: SagaCopyV1Fixture.copy.answeredOccasionIDs,
            madeAt: SagaCopyV1Fixture.copy.madeAt
        ))
        for (original, new) in zip(SagaCopyV1Fixture.photoIDs, ids) {
            #expect(try await photos.storedData(id: new) == Data(contentsOf: SagaCopyV1Fixture.photo(original)))
        }
    }

    /// Records the fixture again. Allowed only until the screens for copies ship (ADR-0057 §4):
    /// `DADSAGA_RECORD_SAGA_COPY_V1=1 swift test --build-system swiftbuild --filter SagaCopyV1FixtureTests`.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DADSAGA_RECORD_SAGA_COPY_V1"] == "1"))
    func record() async throws {
        let directory = SagaCopyV1Fixture.directory
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scratch = FileManager.default.temporaryDirectory.appending(path: "dadsaga-record-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let photos = FilePhotoStore.moments(in: scratch)
        var jpegs: [String: Data] = [:]
        for (index, id) in SagaCopyV1Fixture.photoIDs.enumerated() {
            let stored = try await photos.save(try Self.png(side: 24 + index * 8, shade: Double(index) / 3))
            jpegs[id] = try await photos.storedData(id: stored)
            try jpegs[id]?.write(to: SagaCopyV1Fixture.photo(id))
        }
        let pictures = jpegs
        let made = try await AppleArchiveSagaCopyFiles(folder: scratch.appending(path: "tmp")).write(
            SagaCopyV1Fixture.copy, photo: { id in pictures[id] ?? Data() }, progress: { _ in }
        )
        try FileManager.default.copyItem(at: made.url, to: SagaCopyV1Fixture.file)
    }

    private static func png(side: Int, shade: Double) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: shade, green: 0.5, blue: 1 - shade, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
        _ = CGImageDestinationFinalize(destination)
        return output as Data
    }
}

actor AdoptedIDs {
    private(set) var ids: [String] = []
    func append(_ id: String) { ids.append(id) }
}
