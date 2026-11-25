import AppleArchive
import Application
import CryptoKit
import Domain
import Foundation
import System

/// `SagaCopyFiles` as Apple Archive files in a temporary folder (ADR-0057 §3, §6, §7).
///
/// The archive's stream objects aren't `Sendable`: each is made, used and closed inside one function and never captured
/// by an escaping closure. Cancelling is checked between entries.
public struct AppleArchiveSagaCopyFiles: SagaCopyFiles {
    private let app: String
    private let folder: URL

    /// - Parameters:
    ///   - app: the version and build writing the copy, such as `1.0 (12)`, written in its manifest.
    ///   - folder: where copies are written and picked files are read; emptied by `discardTemporaryFiles`.
    public init(
        app: String,
        folder: URL = FileManager.default.temporaryDirectory.appending(path: "SagaCopies", directoryHint: .isDirectory)
    ) {
        self.app = app
        self.folder = folder
    }

    // MARK: Writing

    @concurrent
    public func write(
        _ copy: SagaCopy,
        photo: @escaping @Sendable (String) async throws -> Data,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> MadeSagaCopy {
        let place = try makeFolder()
        let url = place.appending(path: SagaCopyFormat.fileName(madeAt: copy.madeAt))
        do {
            guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: Self.protection) else {
                throw SagaCopyError.failed
            }
            try await writeArchive(copy, to: url, photo: photo, progress: progress)
            let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
            return MadeSagaCopy(url: url, byteCount: size)
        } catch {
            let spaceLeft = error is ArchiveError ? Self.hasSpace(in: place) : true
            try? FileManager.default.removeItem(at: place)
            throw spaceLeft ? error : SagaCopyError.notEnoughSpace
        }
    }

    /// Apple Archive reports a full disk only as an I/O error. A small write through Foundation tells which it was,
    /// without asking iOS for the free space, a required-reason API (ADR-0057 §6).
    private static func hasSpace(in folder: URL) -> Bool {
        let probe = folder.appending(path: "space-probe")
        defer { try? FileManager.default.removeItem(at: probe) }
        do {
            try Data(count: 256 * 1024).write(to: probe)
            return true
        } catch {
            return SagaCopyError(error) != .notEnoughSpace
        }
    }

    private func writeArchive(
        _ copy: SagaCopy,
        to url: URL,
        photo: @Sendable (String) async throws -> Data,
        progress: @Sendable (Double) -> Void
    ) async throws {
        guard let file = ArchiveByteStream.fileStream(
            path: FilePath(url.path), mode: .writeOnly, options: [.truncate], permissions: [.ownerReadWrite]
        ) else { throw SagaCopyError.failed }
        let closeFile = CloseOnce { try file.close() }
        defer { try? closeFile() }
        guard let compressed = ArchiveByteStream.compressionStream(using: .lzfse, writingTo: file) else {
            throw SagaCopyError.failed
        }
        let closeCompressed = CloseOnce { try compressed.close() }
        defer { try? closeCompressed() }
        guard let encoder = ArchiveStream.encodeStream(writingTo: compressed) else { throw SagaCopyError.failed }
        let closeEncoder = CloseOnce { try encoder.close() }
        defer { try? closeEncoder() }

        let json = JSONEncoder()
        json.outputFormatting = [.sortedKeys]
        var checksums: [String: String] = [:]
        // An entry the reader would refuse for its size is never written: a copy that can't come back is worse than
        // none (ADR-0057 §6).
        func add(_ path: String, _ data: Data, limit: Int) throws {
            guard data.count <= limit else { throw SagaCopyError.failed }
            checksums[path] = Self.sha256(data)
            try Self.writeEntry(path, data, to: encoder)
        }

        try add(
            SagaCopyFormat.manifestPath, json.encode(SagaCopyManifestV1(copy: copy, app: app)),
            limit: SagaCopyFormat.manifestLimit
        )
        try add(SagaCopyFormat.sagaPath, json.encode(SagaCopySagaV1(copy: copy)), limit: SagaCopyFormat.sagaLimit)
        let photoIDs = copy.saga.photoIDs
        for (index, id) in photoIDs.enumerated() {
            try Task.checkCancellation()
            try add(SagaCopyFormat.photoPath(id), await photo(id), limit: SagaCopyFormat.photoLimit)
            progress(Double(index + 1) / Double(photoIDs.count + 1))
        }
        try Task.checkCancellation()
        try Self.writeEntry(SagaCopyFormat.checksumsPath, json.encode(SagaCopyChecksumsV1(sha256: checksums)), to: encoder)
        // In order, and each error surfaces: a full disk shows up here, never as a copy cut short.
        try closeEncoder()
        try closeCompressed()
        try closeFile()
        progress(1)
    }

    /// A regular file with only a path, a type and its data: no dates, owners or permissions travel.
    private static func writeEntry(_ path: String, _ data: Data, to encoder: ArchiveStream) throws {
        let header = ArchiveHeader()
        header.append(.string(key: Key.path, value: path))
        header.append(.uint(key: Key.type, value: UInt64(ArchiveHeader.EntryType.regularFile.rawValue)))
        header.append(.blob(key: Key.data, size: UInt64(data.count)))
        try encoder.writeHeader(header)
        if !data.isEmpty {
            try data.withUnsafeBytes { try encoder.writeBlob(key: Key.data, from: $0) }
        }
    }

    // MARK: Reading

    /// The picked file is copied in first, so a file in iCloud Drive is downloaded and nothing else reads it while the
    /// copy is checked. The local copy is deleted whatever happens.
    @concurrent
    public func read(
        fileAt url: URL,
        adopt: @escaping @Sendable (Data) async throws -> String,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> SagaCopy {
        let place = try makeFolder()
        defer { try? FileManager.default.removeItem(at: place) }
        let local = place.appending(path: "picked.\(SagaCopyFormat.fileExtension)")
        try await Self.copyIn(url, to: local)
        try Task.checkCancellation()
        return try await Self.readArchive(at: local, adopt: adopt, progress: progress)
    }

    private static func readArchive(
        at url: URL,
        adopt: @Sendable (Data) async throws -> String,
        progress: @Sendable (Double) -> Void
    ) async throws -> SagaCopy {
        guard let file = ArchiveByteStream.fileStream(
            path: FilePath(url.path), mode: .readOnly, options: [], permissions: [.ownerReadWrite]
        ) else { throw SagaCopyError.unreadable }
        defer { try? file.close() }
        guard let decompressed = ArchiveByteStream.decompressionStream(readingFrom: file) else {
            throw SagaCopyError.notACopy
        }
        defer { try? decompressed.close() }
        guard let decoder = ArchiveStream.decodeStream(readingFrom: decompressed) else { throw SagaCopyError.notACopy }
        defer { try? decoder.close() }
        // Apple Archive refuses a compressed stream cut short anywhere at its first read, before any entry: a file
        // that starts like one was a copy that didn't finish saving or sending; anything else isn't a copy at all.
        let notWhole: SagaCopyError = startsLikeACompressedArchive(url) ? .incomplete : .notACopy

        var hashes: [String: String] = [:]
        let manifest = try readManifest(from: decoder, orElse: notWhole, hashes: &hashes)
        let copy = try readSaga(from: decoder, madeAt: manifest.madeAt, photoCount: manifest.photoCount, hashes: &hashes)
        let expected = Set(copy.saga.photoIDs)
        var newIDs: [String: String] = [:]
        let checksums = try await readPhotos(from: decoder, expected: expected, hashes: &hashes) { id, data in
            newIDs[id] = try await adopt(data)
            progress(Double(newIDs.count) / Double(expected.count + 1))
        }
        try checkEnd(of: decoder, checksums: checksums, hashes: hashes, allPhotosRead: newIDs.count == expected.count)
        progress(1)
        var restored = copy
        restored.saga = copy.saga.replacingPhotoIDs(newIDs)
        return restored
    }

    /// Apple Archive's compressed streams start with `pbz` and the algorithm's letter (`pbze` for LZFSE).
    private static func startsLikeACompressedArchive(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 3)) == Data("pbz".utf8)
    }

    /// A coordinated read, which downloads a file from iCloud Drive first. It may wait a long time, so it runs on a
    /// queue of its own, never on Swift's threads.
    private static func copyIn(_ url: URL, to destination: URL) async throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let intent = NSFileAccessIntent.readingIntent(with: url, options: [.withoutChanges])
        let coordinator = CoordinatorBox()
        let queue = OperationQueue()
        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                    coordinator.coordinator.coordinate(with: [intent], queue: queue) { error in
                        do {
                            if let error { throw error }
                            try FileManager.default.copyItem(at: intent.url, to: destination)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            } onCancel: {
                // A download from iCloud Drive can take minutes; Cancel stops it here.
                coordinator.coordinator.cancel()
            }
        } catch {
            try Task.checkCancellation()
            throw SagaCopyError(error) == .notEnoughSpace ? SagaCopyError.notEnoughSpace : SagaCopyError.unreadable
        }
    }

    // MARK: Temporary files

    public func discardTemporaryFiles() async {
        try? FileManager.default.removeItem(at: folder)
    }

    /// A folder of its own for each copy, so two never share a name.
    private func makeFolder() throws -> URL {
        let place = folder.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        return place
    }

    /// On iOS the copy is readable only while it is open or the phone is unlocked; it exists only until Settings
    /// closes. macOS, where the package's tests run, refuses to open a file created with a protection class.
    private static var protection: [FileAttributeKey: Any]? {
        #if os(iOS)
        [.protectionKey: FileProtectionType.completeUnlessOpen]
        #else
        nil
        #endif
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Computed: `FieldKey` isn't `Sendable`, so it can't be stored in a static.
    enum Key {
        static var path: ArchiveHeader.FieldKey { ArchiveHeader.FieldKey("PAT") }
        static var type: ArchiveHeader.FieldKey { ArchiveHeader.FieldKey("TYP") }
        static var data: ArchiveHeader.FieldKey { ArchiveHeader.FieldKey("DAT") }
    }
}

/// `NSFileCoordinator` isn't `Sendable`, but its `cancel()` is documented as callable from any thread, which is all the
/// cancellation handler does with it.
private final class CoordinatorBox: @unchecked Sendable {
    let coordinator = NSFileCoordinator()
}

/// Closes a stream once: explicitly on success, so its error surfaces, and by `defer` otherwise.
private final class CloseOnce {
    private var close: (() throws -> Void)?

    init(_ close: @escaping () throws -> Void) {
        self.close = close
    }

    func callAsFunction() throws {
        guard let close else { return }
        self.close = nil
        try close()
    }
}
