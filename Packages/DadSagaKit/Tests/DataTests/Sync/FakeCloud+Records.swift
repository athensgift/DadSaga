import Foundation
@testable import Data

/// Records in the fake iCloud: saving, deleting and fetching as CloudKit answers them, and writing straight into a
/// zone as another iPhone would.
extension FakeCloud {
    // MARK: - What an engine sends

    /// One request. Each save sets only the fields it carries on the record the zone holds; a save with system fields
    /// must name that record as it is now, and one without must be new.
    func modify(_ batch: SyncBatch, as account: String, in database: SyncDatabase) async -> SentRecords {
        if let happens = whileNextRequestIsOut {
            whileNextRequestIsOut = nil
            await happens()
        }
        var sent = SentRecords()
        requests.append(batch.saves.map(\.name) + batch.deletions.map(\.name))
        for record in batch.saves {
            switch save(record, as: account, in: database) {
            case .success(let saved): sent.saved.append(saved)
            case .failure(let error): sent.failed.append(FailedSave(record: record, error: error))
            }
        }
        for deletion in batch.deletions {
            let id = ZoneID(deletion.zone, for: account)
            guard let zone = zones[id], isVisible(id, zone, to: account, in: database) else {
                sent.failedDeletions.append(FailedDeletion(change: deletion, error: .zoneNotFound))
                continue
            }
            // Deleting a record that isn't there succeeds.
            remove(deletion.name, from: id)
            sent.deleted.append(deletion)
        }
        return sent
    }

    private func save(_ record: SyncRecord, as account: String, in database: SyncDatabase) -> Result<SyncRecord, SyncSaveError> {
        let id = ZoneID(record.zone, for: account)
        guard let zone = zones[id], isVisible(id, zone, to: account, in: database) else { return .failure(.zoneNotFound) }
        let existing = zone.records[record.name]
        if let data = record.systemFields {
            guard let fields = try? JSONDecoder().decode(SystemFields.self, from: data),
                  fields.incarnation == zone.incarnation, let existing else { return .failure(.unknownItem) }
            guard fields.tag == existing.tag else { return .failure(.serverRecordChanged(served(record.name, in: id))) }
        } else if existing != nil {
            return .failure(.serverRecordChanged(served(record.name, in: id)))
        }
        var stored = existing ?? StoredRecord(creator: account)
        stored.set(record)
        let grown = stored.bytes - (existing?.bytes ?? 0)
        if let quota = quotas[id.owner], usage(of: id.owner) + grown > quota { return .failure(.quotaExceeded) }
        put(stored, as: record.name, in: id)
        var saved = record
        saved.systemFields = systemFields(of: record.name, in: id)
        return .success(saved)
    }

    private func put(_ stored: StoredRecord, as name: RecordName, in id: ZoneID) {
        guard var zone = zones[id] else { return }
        var stored = stored
        stored.tag += 1
        zone.sequence += 1
        zone.records[name] = stored
        zone.changed[name] = zone.sequence
        zone.deleted[name] = nil
        zones[id] = zone
    }

    private func remove(_ name: RecordName, from id: ZoneID) {
        guard var zone = zones[id], zone.records.removeValue(forKey: name) != nil else { return }
        zone.sequence += 1
        zone.deleted[name] = zone.sequence
        zone.changed[name] = nil
        zones[id] = zone
    }

    // MARK: - What an engine fetches

    /// The records changed and deleted in a zone since `token`; every record and no deletion with no token, or with
    /// one from before the zone was made again. Nil: the account's database shows no such zone.
    func recordChanges(
        in zone: SyncZone, for account: String, _ database: SyncDatabase, since token: ZoneToken?
    ) -> RecordChanges? {
        let id = ZoneID(zone, for: account)
        guard let state = zones[id], isVisible(id, state, to: account, in: database) else { return nil }
        let since = token?.incarnation == state.incarnation ? token?.sequence : nil
        var modified = state.changed.filter { $0.value > since ?? 0 }.sorted { $0.value < $1.value }.map(\.key)
        var deleted = since.map { since in state.deleted.filter { $0.value > since }.sorted { $0.value < $1.value }.map(\.key) }
        if deliversInReverse { (modified, deleted) = (modified.reversed(), deleted?.reversed()) }
        return RecordChanges(
            modified: modified.map { served($0, in: id) }, deleted: deleted ?? [],
            token: ZoneToken(incarnation: state.incarnation, sequence: state.sequence)
        )
    }

    /// The record as a fetch or a conflict hands it over: whole, with its system fields and creator, and a photo's
    /// bytes in a file of their own.
    private func served(_ name: RecordName, in id: ZoneID) -> SyncRecord {
        guard let stored = zones[id]?.records[name] else { return SyncRecord(name: name, zone: id.zone) }
        var record = SyncRecord(
            name: name, zone: id.zone, fields: stored.fields, systemFields: systemFields(of: name, in: id),
            creator: stored.creator
        )
        if let asset = stored.asset {
            let file = downloads.appending(path: UUID().uuidString + ".jpg")
            try? FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
            try? asset.write(to: file)
            record.asset = file
        }
        return record
    }

    private func systemFields(of name: RecordName, in id: ZoneID) -> Data? {
        guard let zone = zones[id], let stored = zone.records[name] else { return nil }
        let encoder = JSONEncoder()
        // The same bytes for the same record every time: tests compare system fields.
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(SystemFields(incarnation: zone.incarnation, name: name.string, tag: stored.tag))
    }

    // MARK: - For tests

    /// Another iPhone of `account`, or a newer version of the app, saves `record`: its fields are set on what the
    /// zone holds, which is made when the account's own database lacks it.
    func write(_ record: SyncRecord, as account: String) {
        let id = ZoneID(record.zone, for: account)
        saveZone(record.zone, as: account)
        guard zones[id] != nil else { return }
        var stored = zones[id]?.records[record.name] ?? StoredRecord(creator: account)
        stored.set(record)
        put(stored, as: record.name, in: id)
    }

    /// Another iPhone deletes the record.
    func delete(_ name: RecordName, in zone: SyncZone, as account: String) {
        remove(name, from: ZoneID(zone, for: account))
    }

    /// The record as the zone holds it; nil when it holds none.
    func record(_ name: RecordName, in zone: SyncZone, of account: String) -> SyncRecord? {
        let id = ZoneID(zone, for: account)
        return zones[id]?.records[name] == nil ? nil : served(name, in: id)
    }

    /// Every record's fields in a zone, by name.
    func records(in zone: SyncZone, of account: String) -> [RecordName: [String: SyncValue]] {
        zones[ZoneID(zone, for: account)]?.records.mapValues(\.fields) ?? [:]
    }

    /// The bytes of a photo the zone holds.
    func asset(of name: RecordName, in zone: SyncZone, of account: String) -> Data? {
        zones[ZoneID(zone, for: account)]?.records[name]?.asset
    }
}

private extension FakeCloud.StoredRecord {
    /// A save sets only the fields it carries, and `.cleared` removes one: a field it doesn't carry stays.
    mutating func set(_ record: SyncRecord) {
        for (field, value) in record.fields { fields[field] = value == .cleared ? nil : value }
        if let file = record.asset, let bytes = try? Data(contentsOf: file) { asset = bytes }
    }
}
