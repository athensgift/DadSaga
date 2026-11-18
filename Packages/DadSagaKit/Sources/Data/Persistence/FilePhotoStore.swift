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

    private let directory: URL
    private let maxPixelSize: Int

    /// - Parameters:
    ///   - directory: where the files live; created on first save.
    ///   - maxPixelSize: longest side of a stored photo, in pixels.
    public init(directory: URL, maxPixelSize: Int = 2048) {
        self.directory = directory
        self.maxPixelSize = maxPixelSize
    }

    /// The photos of legendary moments, in `directory` (the folder the app shares with the widget, ADR-0023).
    public static func moments(in directory: URL) -> FilePhotoStore {
        FilePhotoStore(directory: directory.appending(path: "MomentPhotos", directoryHint: .isDirectory))
    }

    public func save(_ imageData: Data) async throws -> String {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { throw PhotoError.notAnImage }
        let jpeg = try Self.downscaledJPEG(from: source, maxPixelSize: maxPixelSize)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID().uuidString
        try jpeg.write(to: url(for: id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return id
    }

    /// Decodes only a downscaled image straight from the file, so the full photo never sits in memory.
    public func thumbnail(id: String, maxPixelSize: Int) async -> Data? {
        guard let source = CGImageSourceCreateWithURL(url(for: id) as CFURL, nil) else { return nil }
        return try? Self.downscaledJPEG(from: source, maxPixelSize: maxPixelSize)
    }

    public func delete(id: String) async {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    public func deleteAll() async {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Ids are UUIDs we generated; anything else (e.g. a path) is reduced to its last component so it stays inside.
    private func url(for id: String) -> URL {
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
