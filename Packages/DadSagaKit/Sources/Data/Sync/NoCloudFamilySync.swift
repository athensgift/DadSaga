import Application
import Foundation
import os

/// The `FamilySync` of a build with no iCloud (ADR-0081): nothing leaves the iPhone, and `resume()` trims the saga
/// store's history at launch, so it never grows (ADR-0065 §2). The build that wires sync puts `SyncCoordinator` in
/// its place and deletes it: a trim beside the coordinator would expire the token sync reads from.
public struct NoCloudFamilySync: FamilySync {
    private static let logger = Logger(subsystem: "DadSaga", category: "store")

    let connection: StoreConnection

    public init(store: LocalStore) {
        connection = store.connection
    }

    public func status() async -> ShareStatus {
        ShareStatus(sharing: .off)
    }

    /// Off the caller's actor, as the repositories are: a model actor runs a call on the thread that enqueued it.
    /// A failure is logged and the launch goes on; the next launch tries again.
    @concurrent public func resume() async {
        do {
            try await connection.open().feed.trim()
        } catch {
            Self.logger.error("The history was not trimmed: \(error.syncLogLabel, privacy: .public)")
        }
    }
}
