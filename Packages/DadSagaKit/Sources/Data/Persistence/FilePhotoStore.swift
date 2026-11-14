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

    /// The app's photo folder, inside Application Support.
    public static func appDefault() -> FilePhotoStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return FilePhotoStore(directory: base.appending(path: "MomentPhotos", directoryHint: .isDirectory))
    }

    public func save(_ imageData: Data) async throws -> String {
        let jpeg = try Self.downscaledJPEG(from: imageData, maxPixelSize: maxPixelSize)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID().uuidString
        try jpeg.write(to: url(for: id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return id
    }

    public func load(id: String) async -> Data? {
        try? Data(contentsOf: url(for: id))
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

    private static func downscaledJPEG(from data: Data, maxPixelSize: Int) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw PhotoError.notAnImage }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
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
