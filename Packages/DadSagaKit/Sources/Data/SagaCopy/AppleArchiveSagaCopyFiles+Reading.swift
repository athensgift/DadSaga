import AppleArchive
import Application
import Domain
import Foundation

/// Reading a copy, entry by entry, in the order format 1 writes them (ADR-0057 §3, §7). Each step refuses what it
/// doesn't expect before the next one starts.
extension AppleArchiveSagaCopyFiles {
    /// Anything that isn't a manifest is not a copy; a newer one goes no further. A first entry that can't be read at
    /// all is `unreadable`.
    static func readManifest(
        from decoder: ArchiveStream, orElse unreadable: SagaCopyError, hashes: inout [String: String]
    ) throws -> SagaCopyManifestV1 {
        let entry: Entry
        do {
            guard let first = try nextEntry(from: decoder, limit: SagaCopyFormat.manifestLimit),
                  first.path == SagaCopyFormat.manifestPath else { throw SagaCopyError.notACopy }
            entry = first
        } catch let error as SagaCopyError {
            throw error
        } catch {
            throw unreadable
        }
        let json = JSONDecoder()
        guard let head = try? json.decode(SagaCopyManifestHead.self, from: entry.data),
              head.kind == SagaCopyFormat.kind else { throw SagaCopyError.notACopy }
        guard head.formatVersion <= SagaCopyFormat.currentVersion else { throw SagaCopyError.newerFormat }
        guard head.formatVersion == 1, let manifest = try? json.decode(SagaCopyManifestV1.self, from: entry.data) else {
            throw SagaCopyError.damaged
        }
        hashes[entry.path] = sha256(entry.data)
        return manifest
    }

    /// The saga, checked whole before any photo is stored.
    static func readSaga(
        from decoder: ArchiveStream, madeAt: Double, photoCount: Int, hashes: inout [String: String]
    ) throws -> SagaCopy {
        let entry = try nextEntry(from: decoder, limit: SagaCopyFormat.sagaLimit, orElse: .incomplete)
        guard entry.path == SagaCopyFormat.sagaPath,
              let dto = try? JSONDecoder().decode(SagaCopySagaV1.self, from: entry.data) else { throw SagaCopyError.damaged }
        hashes[entry.path] = sha256(entry.data)
        let copy = try dto.toDomain(madeAt: Date(timeIntervalSinceReferenceDate: madeAt))
        do { try SagaCopyRules.checked(copy.saga) } catch { throw SagaCopyError.damaged }
        let photoIDs = Set(copy.saga.photoIDs)
        guard photoIDs.count == photoCount, photoIDs.allSatisfy({ UUID(uuidString: $0) != nil }) else {
            throw SagaCopyError.damaged
        }
        return copy
    }

    /// Each photo named by the saga, once, handed to `store` as it comes. Returns the checksums entry that follows them.
    static func readPhotos(
        from decoder: ArchiveStream,
        expected: Set<String>,
        hashes: inout [String: String],
        store: (String, Data) async throws -> Void
    ) async throws -> Entry {
        var seen: Set<String> = []
        while true {
            try Task.checkCancellation()
            let entry = try nextEntry(from: decoder, limit: SagaCopyFormat.photoLimit, orElse: .incomplete)
            if entry.path == SagaCopyFormat.checksumsPath { return entry }
            guard let id = SagaCopyFormat.photoID(inPath: entry.path), expected.contains(id),
                  seen.insert(id).inserted else { throw SagaCopyError.damaged }
            hashes[entry.path] = sha256(entry.data)
            do {
                try await store(id, entry.data)
            } catch let error as CancellationError {
                throw error
            } catch let error as FilePhotoStore.PhotoError {
                // The copy's photo isn't one the app could have stored.
                throw error == .notAnImage ? SagaCopyError.damaged : SagaCopyError.failed
            } catch {
                // The phone couldn't store it: not the file's fault.
                throw SagaCopyError(error)
            }
        }
    }

    /// Every photo read, the checksums matching everything before them, and nothing after them.
    static func checkEnd(
        of decoder: ArchiveStream, checksums: Entry, hashes: [String: String], allPhotosRead: Bool
    ) throws {
        guard allPhotosRead,
              let sums = try? JSONDecoder().decode(SagaCopyChecksumsV1.self, from: checksums.data),
              sums.sha256 == hashes else { throw SagaCopyError.damaged }
        let after: Entry?
        do { after = try nextEntry(from: decoder, limit: 0) } catch { throw SagaCopyError.damaged }
        guard after == nil else { throw SagaCopyError.damaged }
    }

    struct Entry: Equatable {
        let path: String
        let data: Data
    }

    /// The next entry, refused as `.damaged` unless it is a regular file with a path and data within `limit`. A read
    /// that fails, or no entry, is `missing`.
    static func nextEntry(from decoder: ArchiveStream, limit: Int, orElse missing: SagaCopyError) throws -> Entry {
        let entry: Entry?
        do {
            entry = try nextEntry(from: decoder, limit: limit)
        } catch let error as SagaCopyError {
            throw error
        } catch {
            throw missing
        }
        guard let entry else { throw missing }
        return entry
    }

    /// `nil` at the end of the archive.
    static func nextEntry(from decoder: ArchiveStream, limit: Int) throws -> Entry? {
        guard let header = try decoder.readHeader() else { return nil }
        guard header.entryType == .regularFile,
              case .string(_, let path)? = header.field(forKey: Key.path),
              case .blob(_, let size, _)? = header.field(forKey: Key.data) else { throw SagaCopyError.damaged }
        guard size <= UInt64(limit) else { throw SagaCopyError.damaged }
        var data = Data(count: Int(size))
        if size > 0 {
            try data.withUnsafeMutableBytes { try decoder.readBlob(key: Key.data, into: $0) }
        }
        return Entry(path: path, data: data)
    }
}
