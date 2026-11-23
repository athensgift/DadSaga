import Domain
import Foundation
import SwiftData

/// What a fetch brought: records as far as they came, and the names of records deleted in their zone.
struct FetchedBatch: Hashable, Sendable {
    var records: [SyncRecord] = []
    var deletions: [RecordName] = []
}

/// What the applier is told with a batch (ADR-0065 §4).
struct ApplyContext: Sendable {
    /// The fields whose local change waits in `Sync.store`, by record (`SyncLedger.waitingFields`).
    let waiting: [RecordName: Set<String>]
    /// The history was read through this token: the dad's changes after it wait too, though no one has read them yet.
    let historyToken: DefaultHistoryToken?
    /// The children deleted for good that `Sync.store` knows.
    let gone: Set<UUID>
    let catalog: ContentCatalog
    /// A join's or a follow's child map that still waits: it is applied with the batch that brings the last of the
    /// family's children it names, in the same save, so the family is never read with a child twice or with none.
    var map: ChildMap?
}

/// What applying a batch left for the coordinator to do.
struct Applied: Hashable, Sendable {
    /// The photos of entries that went, that no entry lists any more: their files go.
    var photosToDelete: [String] = []
    /// Changes that came and were not applied, to send again: the removal that would have left no child in the
    /// family, and the marker of a child deleted for good whose record came without it.
    var resend: [LocalChange] = []
    /// Records to delete from the zone: an entry of a child deleted for good, and the photos it names.
    var deleteFromZone: [RecordName] = []
    /// Children whose `gone` marker came and `Sync.store` didn't know.
    var goneLearned: [UUID] = []
    /// Whether a row changed: the widget reloads on it.
    var changedSomething = false
    /// The context's child map as it was applied with this batch; nil: it still waits, or there was none.
    var mapped: ChildMap?
}

enum SyncApplyError: Error, Equatable {
    /// The history after the context's token can't be read, so what the dad changed since can't be left alone:
    /// nothing was applied.
    case historyTokenExpired
}

/// Writes what sync fetched into the saga store (ADR-0065 §2, §4), as an actor on the store's one queue (ADR-0068).
/// Each batch is one turn: every row is fetched by its id, and only the fields that came and differ are set, none
/// whose local change still waits. `#Unique` guards the rows; it is never how one is written, since an upsert would
/// overwrite the waiting fields. Its saves carry the `sync` author, so the change feed never reads them as the dad's.
///
/// Rows go only for a deletion fetched from the zone, a fetched `gone` marker, or a child map the parent confirmed.
/// Before a batch deletes this parent's own entries, their title is kept in a save of its own under no author, which
/// the change feed sends (ADR-0055 §3): a title never goes down.
actor SwiftDataSyncApplier: SagaStoreActor {
    nonisolated let modelExecutor: any ModelExecutor
    nonisolated let modelContainer: ModelContainer

    init(queue: DefaultSerialModelExecutor, container: ModelContainer) {
        modelExecutor = queue
        modelContainer = container
    }

    /// One turn. Throws `SyncApplyError.historyTokenExpired`, applying nothing, when the history after the context's
    /// token is gone. If keeping the title fails, nothing is applied either.
    func apply(_ batch: FetchedBatch, _ context: ApplyContext) throws -> Applied {
        var turn = try Turn(batch, context, unread: modelContext.localChanges(after: context.historyToken))
        try keepTitle(before: turn)
        let changed = try modelContext.saveAllOrNothing(as: .sync) {
            let children = try applyChildren(&turn)
            if let map = turn.map { turn.applied.mapped = try move(by: map, among: children, onlyWhole: true) }
            try applyEntries(&turn)
            try applyHero(turn)
            try applyWardrobe(turn)
            try applyDeletions(&turn)
            return modelContext.hasChanges
        }
        turn.applied.changedSomething = changed
        turn.applied.photosToDelete = try unlisted(turn.photosOfDeletedEntries)
        return turn.applied
    }

    /// A join or a follow (ADR-0065 §4), for the children whose family's child is here: each one's entries move to the
    /// family's child, keeping their ids, and their own row goes, under `sync`, so the change feed never reads it as
    /// deleted for good. A child whose family's child is not here stays as they are: nothing they have is hidden or
    /// dropped. Returns the part of the map that was applied.
    func apply(_ map: ChildMap) throws -> ChildMap {
        guard !map.moves.isEmpty else { return ChildMap() }
        return try modelContext.saveAllOrNothing(as: .sync) {
            let children = Dictionary(
                try modelContext.fetch(FetchDescriptor<ChildRecord>()).map { ($0.childID, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            return try move(by: map, among: children, onlyWhole: false) ?? ChildMap()
        }
    }

    /// Inside a save. `onlyWhole`: nothing moves, and nil is returned, unless every family's child the map names is
    /// among `children`. Every entry moves by the child it had before the map, whatever order the map is read in.
    private func move(by map: ChildMap, among children: [UUID: ChildRecord], onlyWhole: Bool) throws -> ChildMap? {
        let moves = map.moves.filter { children[$0.value] != nil }
        if onlyWhole, moves.count != map.moves.count { return nil }
        let mapped = Array(moves.keys)
        guard !mapped.isEmpty else { return ChildMap() }
        let entries = try modelContext.fetch(FetchDescriptor<ProgressEventRecord>(
            predicate: #Predicate { mapped.contains($0.childID) }
        ))
        for entry in entries {
            if let family = moves[entry.childID] { entry.update(\.childID, to: family) }
        }
        for own in mapped {
            if let row = children[own] { modelContext.delete(row) }
        }
        return ChildMap(familyIDs: moves)
    }

    // MARK: - The title first

    /// Keeps the title this parent holds when the batch deletes entries of theirs: fetched deletions, and the entries
    /// of a child that comes `gone`. Never built for another author (ADR-0065 §3).
    private func keepTitle(before turn: Turn) throws {
        let (goingEntries, goingChildren) = (turn.deletedEntryIDs, turn.goneChildIDs)
        // Most batches delete nothing: no entry is read for them.
        guard !goingEntries.isEmpty || !goingChildren.isEmpty,
              let profile = try modelContext.fetch(FetchDescriptor<ProfileRecord>()).first else { return }
        let entries = try modelContext.fetch(FetchDescriptor<ProgressEventRecord>())
        let ownID = profile.profileID
        guard entries.contains(where: {
            $0.authorID == ownID && (goingEntries.contains($0.eventID) || goingChildren.contains($0.childID))
        }) else { return }
        let standing = DadStanding(
            progress: DadProgress(
                of: profile.toDomain(children: [], removedChildren: []), events: entries.compactMap { $0.toDomain() },
                catalog: turn.catalog
            ),
            catalog: turn.catalog, kept: profile.kept
        )
        guard let title = standing.titleToKeep else { return }
        try modelContext.saveAllOrNothing {
            profile.update(\.heldTitleID, to: profile.kept.keeping(titleID: title.id, catalog: turn.catalog).titleID)
        }
    }

    // MARK: - Records

    /// Returns the children's rows as the batch leaves them.
    private func applyChildren(_ turn: inout Turn) throws -> [UUID: ChildRecord] {
        var rows = Dictionary(
            try modelContext.fetch(FetchDescriptor<ChildRecord>()).map { ($0.childID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let hadFamily = rows.values.contains { !$0.isRemoved }
        var removals: [ChildRecord] = []
        for record in turn.records where record.name.type == .child {
            guard let id = record.name.uuid else { continue }
            if record.isGoneMarker {
                try deleteForGood(id, row: rows.removeValue(forKey: id), &turn)
            } else if turn.gone.contains(id) {
                // A save onto a child deleted for good is ignored: `gone` is final. The zone holds their record
                // without the marker (an iPhone that was off sent it), so the marker goes again.
                turn.applied.resend.append(.gone(childID: id))
            } else if let row = rows[id] {
                var fields = turn.fieldsToSet(record, on: row)
                if fields[SyncField.Child.isRemoved] == .bool(true) {
                    fields[SyncField.Child.isRemoved] = nil
                    removals.append(row)
                }
                row.set(fields)
            } else if let row = insert(record, turn, { ChildRecord.inserted(childID: id, from: $0) }) {
                rows[id] = row
            }
        }
        // A family with no child before the batch is left as it is.
        if hadFamily { applyRemovals(removals, among: Array(rows.values), &turn) }
        return rows
    }

    /// A removal that would leave no child in the family is not applied (ADR-0065 §4): the child whose removal came
    /// last stays, and is sent again. Nothing else brings a child back: when it is a `gone` marker that takes the
    /// family's last child, the family has none until a parent adds one or brings one back.
    private func applyRemovals(_ removals: [ChildRecord], among rows: [ChildRecord], _ turn: inout Turn) {
        let removing = Set(removals.map(\.childID))
        let staying = rows.contains { !$0.isRemoved && !removing.contains($0.childID) } ? nil : removals.last
        for row in removals where row !== staying { row.update(\.isRemoved, to: true) }
        if let staying { turn.applied.resend.append(.save(staying.recordName, fields: [SyncField.Child.isRemoved])) }
    }

    /// A `gone` marker: the child and every entry with them, whoever recorded it (ADR-0065 §4).
    private func deleteForGood(_ childID: UUID, row: ChildRecord?, _ turn: inout Turn) throws {
        let entries = try modelContext.fetch(FetchDescriptor<ProgressEventRecord>(
            predicate: #Predicate { $0.childID == childID }
        ))
        for entry in entries {
            turn.photosOfDeletedEntries += entry.photoIDs
            modelContext.delete(entry)
        }
        if let row { modelContext.delete(row) }
        if turn.gone.insert(childID).inserted { turn.applied.goneLearned.append(childID) }
    }

    /// An entry is stored even while its child has no row yet: the timeline lists only the family's children. One whose
    /// child is gone is never stored, and is deleted from the zone with the photos it names, so a stale iPhone's late
    /// upload doesn't stay there.
    private func applyEntries(_ turn: inout Turn) throws {
        let records = turn.records.filter { $0.name.type == .entry }
        let ids = records.compactMap(\.name.uuid)
        guard !ids.isEmpty else { return }
        let stored = try modelContext.fetch(FetchDescriptor<ProgressEventRecord>(
            predicate: #Predicate { ids.contains($0.eventID) }
        ))
        let rows = Dictionary(stored.map { ($0.eventID, $0) }, uniquingKeysWith: { first, _ in first })
        for record in records {
            guard let id = record.name.uuid else { continue }
            let row = rows[id]
            if let childID = record.entryChildID ?? row?.childID, turn.gone.contains(childID) {
                turn.applied.deleteFromZone.append(record.name)
                if case .strings(let photoIDs)? = record.fields[SyncField.Entry.photoIDs] {
                    turn.applied.deleteFromZone += photoIDs.map(RecordName.photo)
                }
            } else if let row {
                row.set(turn.fieldsToSet(record, on: row))
            } else {
                _ = insert(record, turn) { ProgressEventRecord.inserted(eventID: id, from: $0) }
            }
        }
    }

    /// Only this iPhone's own hero: Personal holds this parent's only, and another profile's is ignored. A hero is
    /// never inserted or deleted by sync.
    private func applyHero(_ turn: Turn) throws {
        guard let profile = try modelContext.fetch(FetchDescriptor<ProfileRecord>()).first else { return }
        for record in turn.records where record.name == profile.recordName {
            profile.set(turn.fieldsToSet(record, on: profile))
        }
    }

    private func applyWardrobe(_ turn: Turn) throws {
        for record in turn.records where record.name.type == .wardrobe {
            let skill = record.name.id
            if let row = try modelContext.row(OutfitRecord.self, #Predicate { $0.skill == skill }) {
                row.set(turn.fieldsToSet(record, on: row))
            } else {
                _ = insert(record, turn) { OutfitRecord.inserted(skill: skill, from: $0) }
            }
        }
    }

    /// The row of a record that has none, when the record brings what a row needs. Not while a change of the record
    /// waits: it has no row because the dad deleted it, and his deletion goes after this.
    private func insert<Row: SyncedRow>(_ record: SyncRecord, _ turn: Turn, _ row: ([String: SyncValue]) -> Row?) -> Row? {
        guard turn.waiting[record.name] == nil,
              let row = row(FieldMerge.fieldsToSet(record, stored: nil, waiting: [], catalog: turn.catalog)) else { return nil }
        modelContext.insert(row)
        return row
    }

    // MARK: - Deletions

    /// An entry and a wardrobe slot go with their record, whatever waits for them: a deletion wins over an edit made
    /// at the same time (ADR-0065 §4). A child leaves only by `gone`, and a hero never; the other records are not rows.
    private func applyDeletions(_ turn: inout Turn) throws {
        let entryIDs = Array(turn.deletedEntryIDs)
        if !entryIDs.isEmpty {
            let entries = try modelContext.fetch(FetchDescriptor<ProgressEventRecord>(
                predicate: #Predicate { entryIDs.contains($0.eventID) }
            ))
            for entry in entries {
                turn.photosOfDeletedEntries += entry.photoIDs
                modelContext.delete(entry)
            }
        }
        for name in turn.deletions where name.type == .wardrobe {
            let skill = name.id
            if let row = try modelContext.row(OutfitRecord.self, #Predicate { $0.skill == skill }) { modelContext.delete(row) }
        }
    }

    /// Those of `photoIDs` no entry lists now, once each, read after the save.
    func unlisted(_ photoIDs: [String]) throws -> [String] {
        guard !photoIDs.isEmpty else { return [] }
        var listed = Set(try modelContext.fetch(FetchDescriptor<ProgressEventRecord>()).flatMap(\.photoIDs))
        return photoIDs.filter { listed.insert($0).inserted }
    }
}

/// One batch being applied: what came, what must be left alone, and what is found on the way.
private struct Turn {
    /// One record per name, in the order they came; a name that came twice holds the later value of each field.
    let records: [SyncRecord]
    let deletions: [RecordName]
    let catalog: ContentCatalog
    /// The fields whose local change waits: in `Sync.store`, or in the history not read yet. A record whose deletion
    /// waits has every field waiting.
    private(set) var waiting: [RecordName: Set<String>]
    /// The children deleted for good: known to `Sync.store`, by the dad since the history was last read, and learned
    /// from this batch as it goes.
    var gone: Set<UUID>
    /// The child map that waits for the family's children.
    let map: ChildMap?
    var photosOfDeletedEntries: [String] = []
    var applied = Applied()

    init(_ batch: FetchedBatch, _ context: ApplyContext, unread: FeedRead) throws {
        guard case .changes(let changes, _) = unread else { throw SyncApplyError.historyTokenExpired }
        var names: [RecordName] = []
        var byName: [RecordName: SyncRecord] = [:]
        for record in batch.records {
            if byName[record.name] == nil { names.append(record.name) }
            byName[record.name, default: record].fields.merge(record.fields) { _, later in later }
        }
        records = names.compactMap { byName[$0] }
        deletions = batch.deletions
        catalog = context.catalog
        waiting = context.waiting
        gone = context.gone
        map = context.map
        for change in changes {
            switch change {
            case .save(let name, let fields): waiting[name, default: []].formUnion(fields ?? SyncField.all(of: name.type))
            case .delete(let name): waiting[name, default: []].formUnion(SyncField.all(of: name.type))
            case .gone(let childID): gone.insert(childID)
            case .entryPhotos: break
            }
        }
    }

    var deletedEntryIDs: Set<UUID> { Set(deletions.filter { $0.type == .entry }.compactMap(\.uuid)) }
    var goneChildIDs: Set<UUID> { Set(records.filter(\.isGoneMarker).compactMap(\.name.uuid)) }

    func fieldsToSet<Row: SyncedRow>(_ record: SyncRecord, on row: Row) -> [String: SyncValue] {
        FieldMerge.fieldsToSet(record, stored: row.syncFields, waiting: waiting[record.name] ?? [], catalog: catalog)
    }
}

private extension SyncRecord {
    /// What is left of a child deleted for good (ADR-0065 §4).
    var isGoneMarker: Bool { name.type == .child && fields[SyncField.Child.gone] == .bool(true) }

    /// The child an entry's record names, when it brings one.
    var entryChildID: UUID? {
        guard case .string(let id)? = fields[SyncField.Entry.childID] else { return nil }
        return UUID(uuidString: id)
    }
}
