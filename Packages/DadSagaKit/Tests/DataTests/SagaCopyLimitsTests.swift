import Foundation
import Testing
@testable import Data

/// Each entry of a copy is refused past its own limit, by the size its header gives, before it is read
/// (ADR-0057 §7).
@Suite("A copy's limits", .serialized)
struct SagaCopyLimitsTests: SagaCopyBench {
    let root = FileManager.default.temporaryDirectory.appending(path: "dadsaga-limits-" + UUID().uuidString)
    let madeAt = Date(timeIntervalSinceReferenceDate: 815_000_000)

    @Test("Given a manifest larger than its limit, when importing, then it is refused before it is read")
    func oversizedEntriesAreRefused() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        var (entries, target) = try await entries()
        entries[0].1 += Data(repeating: 0x20, count: SagaCopyFormat.manifestLimit)

        try await expectRefused(try ArchiveFiles.write(entries, in: root), on: target, as: [.damaged])
    }

    @Test("Given a saga larger than its limit, when importing, then it is refused before it is read")
    func oversizedSagaIsRefused() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        var (entries, target) = try await entries()
        let saga = try #require(entries.firstIndex { $0.0 == SagaCopyFormat.sagaPath })
        // Spaces after the JSON: still a saga that decodes, so only its size can refuse it.
        entries[saga].1 += Data(repeating: 0x20, count: SagaCopyFormat.sagaLimit)

        try await expectRefused(try ArchiveFiles.write(entries, in: root), on: target, as: [.damaged])
    }

    @Test("Given a photo larger than its limit, when importing, then it is refused before it is read")
    func oversizedPhotoIsRefused() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        var (entries, target) = try await entries()
        let photo = try #require(entries.firstIndex { $0.0.hasPrefix("photos/") })
        entries[photo].1 += Data(count: SagaCopyFormat.photoLimit)

        try await expectRefused(try ArchiveFiles.write(entries, in: root), on: target, as: [.damaged])
    }

    /// With the two refusals above, each entry is held to its own limit: a limit swapped for a smaller one fails here.
    @Test("Given a saga past the manifest's limit and a photo past the saga's, when importing, then the copy opens")
    func eachEntryHasItsOwnLimit() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        var (entries, target) = try await entries()
        let saga = try #require(entries.firstIndex { $0.0 == SagaCopyFormat.sagaPath })
        let photo = try #require(entries.firstIndex { $0.0.hasPrefix("photos/") })
        entries[saga].1 += Data(repeating: 0x20, count: SagaCopyFormat.manifestLimit)
        entries[photo].1 += Data(count: SagaCopyFormat.sagaLimit)

        _ = try await restore(on: target).open(fileAt: try ArchiveFiles.write(entries, in: root)) { _ in }
    }
}
