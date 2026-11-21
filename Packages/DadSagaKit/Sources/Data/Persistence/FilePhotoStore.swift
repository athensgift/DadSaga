import Application
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// `PhotoStore` that keeps photos as JPEG files in a folder on the device. Photos are downscaled on the way in:
/// a moment needs a good picture, not the camera's full resolution.
public actor FilePhotoStore: PhotoStore {
    public enum PhotoError: Error, Equatable {
        case notAnImage
    }

    /// Finds the folder the files live in; it throws when there is none (no App Group in a release build).
    private let folder: @Sendable () throws -> URL
    private let maxPixelSize: Int

    /// - Parameters:
    ///   - directory: where the files live; created on first save.
    ///   - maxPixelSize: longest side of a stored photo, in pixels.
    public init(directory: URL, maxPixelSize: Int = 2048) {
        self.init(folder: { directory }, maxPixelSize: maxPixelSize)
    }

    init(folder: @escaping @Sendable () throws -> URL, maxPixelSize: Int = 2048) {
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
