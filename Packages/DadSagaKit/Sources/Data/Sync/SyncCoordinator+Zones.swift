import Foundation

/// A zone that goes by itself (ADR-0065 §4). It never deletes the saga on the iPhone.
extension SyncCoordinator {
    /// A zone of this parent's own database went:
    /// - `purged`, the parent deleted DadSaga's data in iCloud's settings: sync is off, and nothing is uploaded again
    ///   by itself;
    /// - `deleted`, another of the parent's iPhones deleted it (it started over): sync is off here, the saga stays;
    /// - `encryptedDataReset`: the zone is made again under its name and everything it held is sent again.
    func zonesWent(_ deleted: [ZoneDeletion], from database: SyncDatabase, _ ledger: SyncLedger) async throws {
        for deletion in deleted where database == .private {
            let settings = try await ledger.settings()
            guard settings.isOn, let scope = settings.scope(of: deletion.zone),
                  settings.database(for: scope) == database else { continue }
            switch deletion.reason {
            case .purged: try await turnOff(ledger, .purged)
            case .deleted: try await turnOff(ledger, .zoneDeleted)
            case .encryptedDataReset:
                try await ledger.reset(scope, sending: try await everyRecord(in: scope, ledger))
                await engines[database]?.add([.save(deletion.zone)])
                try await give(ledger)
            }
        }
    }

    /// Sync is off until the parent turns iCloud on again: nothing waits, nothing kept of the zones meets a later
    /// one, and the engines are let go. The saga is as it was.
    func turnOff(_ ledger: SyncLedger, _ reason: SyncOffReason) async throws {
        try await ledger.turnOff(reason)
        forgetEngines()
        stopListening()
    }
}
