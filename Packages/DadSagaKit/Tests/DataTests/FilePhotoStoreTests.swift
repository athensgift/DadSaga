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

    @Test("Given no folder for the photos, when saving, then it throws and reading finds nothing")
    func unknownFolderCantSave() async throws {
        let sut = FilePhotoStore(folder: { throw SharedContainerError.appGroupUnavailable })

        await #expect(throws: SharedContainerError.appGroupUnavailable) { try await sut.save(png(width: 10, height: 10)) }
        #expect(await sut.thumbnail(id: "any", maxPixelSize: 100) == nil)
        await sut.delete(id: "any")
        await sut.deleteAll()
    }

    @Test("Given a large image, when saving, then a JPEG no larger than the limit is stored")
    func savesDownscaled() async throws {
        let sut = FilePhotoStore(directory: directory, maxPixelSize: 200)
        defer { try? FileManager.default.removeItem(at: directory) }

        let id = try await sut.save(try png(width: 800, height: 400))

        let stored = try #require(await sut.thumbnail(id: id, maxPixelSize: 4096))
        let size = try pixelSize(of: stored)
        #expect(size.width == 200)
        #expect(size.height == 100)
        #expect(stored.prefix(2) == Data([0xFF, 0xD8]))
    }

    @Test("Given a stored photo, when deleting it, then it can no longer be read")
    func deletes() async throws {
        let sut = FilePhotoStore(directory: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let kept = try await sut.save(try png(width: 10, height: 10))
        let removed = try await sut.save(try png(width: 10, height: 10))

        await sut.delete(id: removed)
        #expect(await sut.thumbnail(id: removed, maxPixelSize: 4096) == nil)
        #expect(await sut.thumbnail(id: kept, maxPixelSize: 4096) != nil)

        await sut.deleteAll()
        #expect(await sut.thumbnail(id: kept, maxPixelSize: 4096) == nil)
    }

    @Test("Given data that is not an image, when saving, then it throws and nothing is written")
    func rejectsNonImage() async throws {
        let sut = FilePhotoStore(directory: directory)
        await #expect(throws: FilePhotoStore.PhotoError.notAnImage) {
            try await sut.save(Data("not an image".utf8))
        }
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test("Given an id that looks like a path, when reading, then nothing outside the folder is read")
    func idsStayInsideTheFolder() async throws {
        let sut = FilePhotoStore(directory: directory)
        #expect(await sut.thumbnail(id: "../../etc/hosts", maxPixelSize: 4096) == nil)
    }

    @Test("Given a stored photo, when asking for a thumbnail, then its longest side is at most the limit")
    func thumbnail() async throws {
        let sut = FilePhotoStore(directory: directory)
        let id = try await sut.save(try png(width: 1200, height: 900))

        let thumbnail = try #require(await sut.thumbnail(id: id, maxPixelSize: 300))

        let size = try pixelSize(of: thumbnail)
        #expect(max(size.width, size.height) == 300)
        #expect(await sut.thumbnail(id: UUID().uuidString, maxPixelSize: 300) == nil)
    }

    @Test("Given a stored photo no larger than asked, when asking for a thumbnail, then the stored file comes back as is")
    func smallPhotoIsNotReencoded() async throws {
        let sut = FilePhotoStore(directory: directory, maxPixelSize: 400)
        let id = try await sut.save(try png(width: 1200, height: 900))
        let stored = try Data(contentsOf: directory.appending(path: id + ".jpg"))

        #expect(await sut.thumbnail(id: id, maxPixelSize: 400) == stored)
        #expect(await sut.thumbnail(id: id, maxPixelSize: 2048) == stored)
        #expect(try pixelSize(of: try #require(await sut.thumbnail(id: id, maxPixelSize: 200))).width == 200)
    }

    @Test("Given saved photos and other files in the folder, when listing, then only the photos come back, with a date")
    func listsOnlyPhotoFiles() async throws {
        let sut = FilePhotoStore(directory: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try await sut.save(try png(width: 10, height: 10))
        let second = try await sut.save(try png(width: 10, height: 10))
        try Data().write(to: directory.appending(path: "notes.txt"))
        try Data().write(to: directory.appending(path: "not-a-uuid.jpg"))
        try FileManager.default.createDirectory(
            at: directory.appending(path: UUID().uuidString + ".jpg"), withIntermediateDirectories: true
        )

        let photos = try await sut.storedPhotos()

        #expect(Set(photos.map(\.id)) == [first, second])
        #expect(photos.allSatisfy { $0.savedAt.map { abs($0.timeIntervalSinceNow) < 60 } == true })
    }

    @Test("Given no photo saved yet, when listing, then there are none")
    func noFolderListsNothing() async throws {
        #expect(try await FilePhotoStore(directory: directory).storedPhotos().isEmpty)
    }

    @Test("Given no folder for the photos, when listing, then it throws")
    func unknownFolderCantList() async throws {
        let sut = FilePhotoStore(folder: { throw SharedContainerError.appGroupUnavailable })

        await #expect(throws: SharedContainerError.appGroupUnavailable) { try await sut.storedPhotos() }
    }

    // MARK: Photos that sync brings (ADR-0065 §1)

    @Test("Given a photo another iPhone stored, when its file is placed, then the same bytes under the same id, as a photo")
    func placeKeepsTheBytesAndTheID() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let other = FilePhotoStore(directory: directory.appending(path: "other"))
        let id = try await other.save(try png(width: 64, height: 48))
        let download = try #require(try await other.fileURL(id: id))
        let sut = FilePhotoStore(directory: directory.appending(path: "here"))

        try await sut.place(fileAt: download, id: id)
        // The same photo fetched again changes nothing.
        try await sut.place(fileAt: download, id: id)

        #expect(try await sut.storedData(id: id) == (try Data(contentsOf: download)))
        #expect(try await sut.storedPhotos().map(\.id) == [id])
        #expect(try await sut.fileURL(id: id) == directory.appending(path: "here").appending(path: id + ".jpg"))
        // The file that came is left where it was: the one who downloaded it clears it.
        #expect(FileManager.default.fileExists(atPath: download.path))
    }

    @Test("Given a file that is no JPEG, or an id that is no UUID, when placing, then it is refused and nothing is written")
    func placeRefusesOtherFilesAndIDs() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let other = FilePhotoStore(directory: directory.appending(path: "other"))
        let jpeg = try #require(try await other.fileURL(id: try await other.save(try png(width: 10, height: 10))))
        let (image, text) = (directory.appending(path: "a.png"), directory.appending(path: "a.txt"))
        try png(width: 10, height: 10).write(to: image)
        try Data("not a photo".utf8).write(to: text)
        let sut = FilePhotoStore(directory: directory.appending(path: "here"))

        await #expect(throws: FilePhotoStore.PhotoError.notAnImage) { try await sut.place(fileAt: image, id: UUID().uuidString) }
        await #expect(throws: FilePhotoStore.PhotoError.notAnImage) { try await sut.place(fileAt: text, id: UUID().uuidString) }
        for id in ["cover", "../" + UUID().uuidString, UUID().uuidString + ".jpg", ""] {
            await #expect(throws: FilePhotoStore.PhotoError.invalidID) { try await sut.place(fileAt: jpeg, id: id) }
        }
        await #expect(throws: (any Error).self) {
            try await sut.place(fileAt: directory.appending(path: "missing.jpg"), id: UUID().uuidString)
        }

        #expect(try await sut.storedPhotos().isEmpty)
    }

    @Test("Given a photo whose file is gone, or an id that is none, when asking for its file, then there is none")
    func noFileForAMissingPhoto() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let sut = FilePhotoStore(directory: directory)
        let id = try await sut.save(try png(width: 10, height: 10))
        await sut.delete(id: id)

        #expect(try await sut.fileURL(id: id) == nil)
        #expect(try await sut.fileURL(id: "../../etc/hosts") == nil)
        await #expect(throws: SharedContainerError.appGroupUnavailable) {
            try await FilePhotoStore(folder: { throw SharedContainerError.appGroupUnavailable }).fileURL(id: id)
        }
    }
}
