import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Data

@Suite("FilePhotoStore")
struct FilePhotoStoreTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-photos-" + UUID().uuidString)

    /// A solid-colour PNG of the given size.
    func png(width: Int, height: Int) throws -> Data {
        let context = try #require(
            CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    func pixelSize(of data: Data) throws -> (width: Int, height: Int) {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return (image.width, image.height)
    }

    @Test("Given a large image, when saving, then a JPEG no larger than the limit is stored and can be loaded")
    func savesDownscaled() async throws {
        let sut = FilePhotoStore(directory: directory, maxPixelSize: 200)
        defer { try? FileManager.default.removeItem(at: directory) }

        let id = try await sut.save(try png(width: 800, height: 400))

        let stored = try #require(await sut.load(id: id))
        let size = try pixelSize(of: stored)
        #expect(size.width == 200)
        #expect(size.height == 100)
        #expect(stored.prefix(2) == Data([0xFF, 0xD8]))
    }

    @Test("Given a stored photo, when deleting it, then it can no longer be loaded")
    func deletes() async throws {
        let sut = FilePhotoStore(directory: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let kept = try await sut.save(try png(width: 10, height: 10))
        let removed = try await sut.save(try png(width: 10, height: 10))

        await sut.delete(id: removed)
        #expect(await sut.load(id: removed) == nil)
        #expect(await sut.load(id: kept) != nil)

        await sut.deleteAll()
        #expect(await sut.load(id: kept) == nil)
    }

    @Test("Given data that is not an image, when saving, then it throws and nothing is written")
    func rejectsNonImage() async throws {
        let sut = FilePhotoStore(directory: directory)
        await #expect(throws: FilePhotoStore.PhotoError.notAnImage) {
            try await sut.save(Data("not an image".utf8))
        }
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test("Given an id that looks like a path, when loading, then nothing outside the folder is read")
    func idsStayInsideTheFolder() async throws {
        let sut = FilePhotoStore(directory: directory)
        #expect(await sut.load(id: "../../etc/hosts") == nil)
    }
}
