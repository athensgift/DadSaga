import Application
import Domain
import Foundation
import SwiftData

/// `ProfileRepository` backed by SwiftData. Created through `LocalStore`.
actor SwiftDataProfileRepository: ProfileRepository, SagaStoreActor {
    nonisolated let modelExecutor: any ModelExecutor
    nonisolated let modelContainer: ModelContainer

    init(queue: DefaultSerialModelExecutor, container: ModelContainer) {
        modelExecutor = queue
        modelContainer = container
    }

    /// The family, and the children removed from it apart (ADR-0065 §4).
    func fetchProfile() async throws -> PlayerProfile? {
        try modelContext.readProfile()
    }

    /// Onboarding: the player and their children, numbered in order, in one save. One player per iPhone (ADR-0065 §5):
    /// throws `ProfileEditError.profileExists` when one is stored. A fetch, not a count: a count also sees an insert a
    /// rollback undid.
    func create(_ profile: PlayerProfile) async throws {
        try modelContext.saveAllOrNothing {
            guard try record() == nil else { throw ProfileEditError.profileExists }
            modelContext.insert(ProfileRecord(profile: profile))
            modelContext.insertChildren(of: profile)
        }
    }

    /// Writes only what the edit names, and only values that differ (ADR-0065 §1, §4): a row the edit doesn't name is
    /// never touched and no child is renumbered. A removed id marks the row removed, its entries kept (ADR-0065 §4); a
    /// removed child is never changed or inserted again, and an id the edit both adds and removes is not added. An
    /// added child goes after the highest stored order, removed rows included. Throws
    /// `ProfileValidationError.noChildren`, writing nothing, when the edit would leave the family without a child, and
    /// `tooManyChildren` when it adds a child past the limit: both checked here, in the write's own turn, against the
    /// rows as stored (ADR-0068 §3). All or nothing: the fetches come between the changes, so the whole body is inside.
    func save(_ edit: FamilyEdit) async throws {
        try modelContext.saveAllOrNothing {
            guard let profile = try record() else { throw ProfileEditError.noProfile }
            if let hasPartner = edit.hasPartner { profile.update(\.hasPartner, to: hasPartner) }

            var stored: [UUID: ChildRecord] = [:]
            for record in try modelContext.fetch(FetchDescriptor<ChildRecord>()) {
                stored[record.childID] = record
            }
            for id in edit.removedIDs { stored[id]?.update(\.isRemoved, to: true) }
            // After the marks: a child removed before or by this edit is never changed.
            for change in edit.changed {
                if let record = stored[change.child.id], !record.isRemoved { record.apply(change) }
            }
            var nextOrder = (stored.values.map(\.order).max() ?? -1) + 1
            var added = 0
            for child in edit.added where stored[child.id] == nil && !edit.removedIDs.contains(child.id) {
                let record = ChildRecord(child: child, order: nextOrder, isRemoved: false)
                modelContext.insert(record)
                stored[child.id] = record
                nextOrder += 1
                added += 1
            }
            let family = stored.values.count(where: { !$0.isRemoved })
            guard family > 0 else { throw ProfileValidationError.noChildren }
            try ProfileRules.checkSize(ofFamily: family, adding: added)
        }
    }

    /// Clears the mark only: the order stays, so the child comes back in their place. Bringing back is adding
    /// (ADR-0065 §4): the limit is checked here, in the write's own turn, against the rows as stored (ADR-0068 §3).
    func bringBack(childID: UUID) async throws {
        try modelContext.saveAllOrNothing {
            let children = try modelContext.fetch(FetchDescriptor<ChildRecord>())
            guard let record = children.first(where: { $0.childID == childID }), record.isRemoved else {
                throw ProfileEditError.notRemoved
            }
            try ProfileRules.checkSize(ofFamily: children.count(where: { !$0.isRemoved }) + 1, adding: 1)
            record.update(\.isRemoved, to: false)
        }
    }

    /// Row by row in one save, never a batch delete (ADR-0057 §7), so each row leaves its id for the change feed
    /// (ADR-0065 §5). No other row is touched.
    func deleteForGood(childID: UUID) async throws -> [String] {
        try modelContext.saveAllOrNothing {
            guard let record = try child(childID), record.isRemoved else { throw ProfileEditError.notRemoved }
            let entries = try modelContext.fetch(FetchDescriptor<ProgressEventRecord>(
                predicate: #Predicate { $0.childID == childID }
            ))
            let photoIDs = entries.flatMap(\.photoIDs)
            for entry in entries { modelContext.delete(entry) }
            modelContext.delete(record)
            return photoIDs
        }
    }

    /// Sets only the hero fields the edit names, and only values that differ. Never a child row.
    func save(_ edit: HeroEdit) async throws {
        try modelContext.saveAllOrNothing {
            guard let profile = try record() else { throw ProfileEditError.noProfile }
            profile.apply(edit)
        }
    }

    private func child(_ id: UUID) throws -> ChildRecord? {
        try modelContext.fetch(FetchDescriptor<ChildRecord>(predicate: #Predicate { $0.childID == id })).first
    }

    private func record() throws -> ProfileRecord? {
        try modelContext.fetch(FetchDescriptor<ProfileRecord>()).first
    }
}
