import Domain
import Foundation

/// Port for the file a copy of the saga lives in (ADR-0057 §3): writing it and reading it back. The format is Data's.
public protocol SagaCopyFiles: Sendable {
    /// Writes `copy` to a new file in the app's temporary folder. `photo` gives each photo's stored bytes as the file
    /// needs them, so only one photo is in memory at a time. Leaves no file when it throws, cancelled included.
    func write(
        _ copy: SagaCopy,
        photo: @escaping @Sendable (String) async throws -> Data,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> MadeSagaCopy

    /// Reads the file at `url`, which the dad picked. Each photo goes to `adopt` as it is read, which stores it and
    /// returns its new id; the copy comes back pointing at those ids. A file that isn't a copy, is a newer format or
    /// holds a saga the rules refuse throws before any photo is adopted.
    func read(
        fileAt url: URL,
        adopt: @escaping @Sendable (Data) async throws -> String,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> SagaCopy

    /// Deletes every file `write` and `read` left in the temporary folder.
    func discardTemporaryFiles() async
}

/// A copy written and ready to be saved or sent.
public struct MadeSagaCopy: Hashable, Sendable {
    public let url: URL
    public let byteCount: Int64

    public init(url: URL, byteCount: Int64) {
        self.url = url
        self.byteCount = byteCount
    }
}

/// Why a copy couldn't be made or read. Each has its own calm message (ADR-0057 §8).
public enum SagaCopyError: Error, Equatable, Sendable {
    /// There is no saga yet.
    case nothingToCopy
    /// The file isn't a DadSaga copy at all.
    case notACopy
    /// The file ends before the copy does: it didn't finish saving or sending.
    case incomplete
    /// The file is a copy, but something in it isn't what was written.
    case damaged
    /// Made by a newer DadSaga, in a format this version can't read.
    case newerFormat
    /// The file couldn't be opened, for example an iCloud Drive file while offline.
    case unreadable
    case notEnoughSpace
    /// Something else failed.
    case failed

    /// `error` as one of these: itself if it is one, a full disk as `.notEnoughSpace`, anything else as `.failed`.
    public init(_ error: any Error) {
        if let error = error as? SagaCopyError {
            self = error
        } else if (error as? CocoaError)?.code == .fileWriteOutOfSpace || (error as? POSIXError)?.code == .ENOSPC {
            self = .notEnoughSpace
        } else {
            self = .failed
        }
    }
}
