import Application
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// `PhotoStore` that keeps photos as JPEG files in a folder on the device. Photos are downscaled on the way in:
/// a moment needs a good picture, not the camera's full resolution.
public actor FilePhotoStore: PhotoStore {
    public enum PhotoError: Error, Equatable {
        case notAnImage
        /// A photo's id is a UUID, as `save` makes it: anything else names no file here.
        case invalidID
    }

    /// Finds the folder the files live in; it throws when there is none (no App Group in a release build).
    private let folder: @Sendable () throws -> URL
    private let maxPixelSize: Int
    /// The longest side of a photo `adopt` takes: generous, since the app stores `StoredPhoto.longestSide` at most.
    private static let adoptedPixelLimit = 8192

    /// - Parameters:
    ///   - directory: where the files live; created on first save.
    ///   - maxPixelSize: longest side of a stored photo, in pixels.
    public init(directory: URL, maxPixelSize: Int = StoredPhoto.longestSide) {
        self.init(folder: { directory }, maxPixelSize: maxPixelSize)
    }

    init(folder: @escaping @Sendable () throws -> URL, maxPixelSize: Int = StoredPhoto.longestSide) {
        self.folder = folder
        self.maxPixelSize = maxPixelSize
    }

    /// The photos of legendary moments, in `directory`.
    public static func moments(in directory: URL) -> FilePhotoStore {
        FilePhotoStore(directory: momentsFolder(in: directory))
    }

    /// The photos of legendary moments, in the folder the app shares with the widget (ADR-0023). Without the App
    /// Group a release build saves nothing and finds nothing (ADR-0048).
    public static func sharedMoments() -> FilePhotoStore {
        FilePhotoStore(folder: { try momentsFolder(in: SharedContainer.directory()) })
    }

    private static func momentsFolder(in directory: URL) -> URL {
        directory.appending(path: "MomentPhotos", directoryHint: .isDirectory)
    }

    public func save(_ imageData: Data) async throws -> String {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { throw PhotoError.notAnImage }
        let jpeg = try Self.downscaledJPEG(from: source, maxPixelSize: maxPixelSize)
        let directory = try folder()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID().uuidString
        try jpeg.write(to: url(for: id, in: directory), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return id
    }

    /// Decodes only a downscaled image straight from the file, so the full photo never sits in memory. A stored photo
    /// no larger than asked is returned as it is, never as a JPEG of a JPEG (ADR-0042 §1).
    public func thumbnail(id: String, maxPixelSize: Int) async -> Data? {
        guard let file = try? url(for: id, in: folder()),
              let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { return nil }
        if let side = Self.longestSide(of: source), side <= maxPixelSize {
            return try? Data(contentsOf: file)
        }
        return try? Self.downscaledJPEG(from: source, maxPixelSize: maxPixelSize)
    }

    /// Read from the file's header, without decoding it. Stored photos are already upright (`save`).
    private static func longestSide(of source: CGImageSource) -> Int? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return max(width, height)
    }

    public func storedData(id: String) async throws -> Data {
        try Data(contentsOf: url(for: id, in: folder()))
    }

    /// Only a JPEG whose header gives its size, so a copy can't bring in a file the app couldn't have written. Written
    /// as `save` writes, with today's date, so the sweep leaves it alone for a day (ADR-0048 §6).
    public func adopt(_ jpeg: Data) async throws -> String {
        let id = UUID().uuidString
        try write(storedJPEG: jpeg, id: id)
        return id
    }

    /// A photo sync fetched, under the id its record names, so the entry that lists it finds it (ADR-0065 §1). The
    /// same check as `adopt`, and the same bytes: the file is copied, never drawn again. The file at `url` is left
    /// where it is. Not on Application's `PhotoStore`: only sync places a photo under an id it didn't make.
    func place(fileAt url: URL, id: String) throws {
        guard UUID(uuidString: id) != nil else { throw PhotoError.invalidID }
        try write(storedJPEG: try Data(contentsOf: url), id: id)
    }

    /// The stored file of a photo, to send as its record's asset; nil when there is none.
    func fileURL(id: String) throws -> URL? {
        let file = url(for: id, in: try folder())
        guard UUID(uuidString: id) != nil, FileManager.default.fileExists(atPath: file.path) else { return nil }
        return file
    }

    /// Only a JPEG whose header gives a size the app could have stored, written as `save` writes.
    private func write(storedJPEG jpeg: Data, id: String) throws {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil), Self.isStorable(source) else {
            throw PhotoError.notAnImage
        }
        let directory = try folder()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try jpeg.write(to: url(for: id, in: directory), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// A JPEG whose header gives a size the app could have stored. Nothing is decoded.
    private static func isStorable(_ source: CGImageSource) -> Bool {
        guard CGImageSourceGetType(source) as String? == UTType.jpeg.identifier,
              let side = longestSide(of: source) else { return false }
        return side <= adoptedPixelLimit
    }

    /// The same check as `adopt`, on each file's header: what this calls readable, a copy of the saga can bring back.
    public func readablePhotos(among ids: Set<String>) async throws -> Set<String> {
        let directory = try folder()
        // The folder is listed first, and that throws as `storedPhotos` does: a folder that can't be read is an
        // error, never a saga without photos.
        let stored = Set(try await storedPhotos().map(\.id))
        var readable: Set<String> = []
        for id in ids.intersection(stored) {
            try Task.checkCancellation()
            if let source = CGImageSourceCreateWithURL(url(for: id, in: directory) as CFURL, nil), Self.isStorable(source) {
                readable.insert(id)
            }
        }
        return readable
    }

    public func delete(id: String) async {
        guard let directory = try? folder() else { return }
        try? FileManager.default.removeItem(at: url(for: id, in: directory))
    }

    public func deleteAll() async {
        guard let directory = try? folder() else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    /// Only files this store wrote: `<UUID>.jpg` regular files, straight inside the folder. No folder yet means no photos; any
    /// other error throws, so a sweep never works from a partial list.
    public func storedPhotos() async throws -> [StoredPhoto] {
        let directory = try folder()
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey]
            )
        } catch CocoaError.fileReadNoSuchFile {
            return []
        }
        return files.compactMap { file in
            let id = file.deletingPathExtension().lastPathComponent
            let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
            guard file.pathExtension == "jpg", UUID(uuidString: id) != nil, values?.isRegularFile == true else { return nil }
            return StoredPhoto(id: id, savedAt: values?.contentModificationDate)
        }
    }

    /// Ids are UUIDs we generated; anything else (e.g. a path) is reduced to its last component so it stays inside.
    private func url(for id: String, in directory: URL) -> URL {
        directory.appending(path: (id as NSString).lastPathComponent + ".jpg")
    }

    private static func downscaledJPEG(from source: CGImageSource, maxPixelSize: Int) throws -> Data {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PhotoError.notAnImage
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw PhotoError.notAnImage
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PhotoError.notAnImage }
        return output as Data
    }
}
