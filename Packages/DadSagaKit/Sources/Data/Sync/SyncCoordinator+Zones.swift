import Foundation

/// A zone that goes by itself (ADR-0065 §4). It never deletes the saga on the iPhone.
extension SyncCoordinator {
    /// A zone of this parent's own database went:
    /// - `purged`, the parent deleted DadSaga's data in iCloud's settings: sync is off, and nothing is uploaded again
    ///   by itself;
    /// - `deleted`, another of the parent's iPhones deleted it: sync is off here and the saga stays, unless it was the
    ///   family's zone and `saga` names another family (that iPhone joined one): then this one waits to follow it;
    /// - `encryptedDataReset`: the zone is made again under its name and everything it held is sent again. When two
    ///   of the parent's iPhones do it, the second's records meet the first's, and they merge by field.
    ///
    /// The family's zone in the partner's iCloud went, whatever the reason: the partner stopped sharing. This parent
    /// keeps everything, in a new zone of their own.
    func zonesWent(_ deleted: [ZoneDeletion], from database: SyncDatabase, _ ledger: SyncLedger) async throws {
        for deletion in deleted {
            let settings = try await ledger.settings()
            guard settings.isOn, let scope = settings.scope(of: deletion.zone),
                  settings.database(for: scope) == database else { continue }
            switch (database, deletion.reason) {
            case (.shared, _): try await familyLeft(ledger)
            case (.private, .purged): try await turnOff(ledger, .purged)
            case (.private, .deleted):
                if scope == .family, try await sagaNamesAnotherFamily(ledger) { continue }
                try await turnOff(ledger, .zoneDeleted)
            case (.private, .encryptedDataReset):
                try await ledger.reset(scope, sending: try await everyRecord(in: scope, ledger))
                await engines[database]?.add([.save(deletion.zone)])
                try await give(ledger)
            }
        }
    }

    /// Whether this parent's `saga` names another family than the one this iPhone syncs with, read by itself: a
    /// fetch reports the zones that went before the records that changed, so `saga` may not have come yet.
    func sagaNamesAnotherFamily(_ ledger: SyncLedger) async throws -> Bool {
        if try await ledger.settings().follow != nil { return true }
        guard let held = try await cloud.sagaRecord() else { return false }
        try await ledger.fetched(FetchOutcome(records: [held]))
        return try await ledger.settings().follow != nil
    }

    /// Sync is off until the parent turns iCloud on again: nothing waits, nothing kept of the zones meets a later
    /// one, and the engines are let go. The saga is as it was.
    func turnOff(_ ledger: SyncLedger, _ reason: SyncOffReason) async throws {
        try await ledger.turnOff(reason)
        forgetEngines()
        stopListening()
    }
}
