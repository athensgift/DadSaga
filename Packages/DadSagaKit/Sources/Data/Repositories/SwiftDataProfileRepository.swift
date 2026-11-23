import Application
import Domain
import Foundation
import SwiftData

/// `ProfileRepository` backed by SwiftData. Created through `LocalStore`.
@ModelActor
actor SwiftDataProfileRepository: ProfileRepository {
    /// The family only: a child removed from it is never read here (ADR-0065 §4).
    func fetchProfile() async throws -> PlayerProfile? {
        guard let record = try record() else { return nil }
        let children = try modelContext
            .fetch(FetchDescriptor<ChildRecord>(
                predicate: #Predicate { $0.isRemoved == false }, sortBy: [SortDescriptor(\.order)]
            ))
            .map { try $0.toDomain() }
        return record.toDomain(children: children)
    }

    /// Onboarding: the player and their children, numbered in order, in one save. One player per iPhone (ADR-0065 §5):
    /// throws `ProfileEditError.profileExists` when one is stored. A fetch, not a count: a count also sees an insert a
    /// rollback undid.
    func create(_ profile: PlayerProfile) async throws {
        try modelContext.saveAllOrNothing {
            guard try record() == nil else { throw ProfileEditError.profileExists }
            modelContext.insert(ProfileRecord(profile: profile))
            for (order, child) in profile.children.enumerated() {
                modelContext.insert(ChildRecord(child: child, order: order, isRemoved: false))
            }
        }
    }

    /// Writes only what the edit names, and only values that differ (ADR-0065 §1, §4): a row the edit doesn't name is
    /// never touched and no child is renumbered. A removed child (ADR-0065 §5) is never changed, deleted or inserted
    /// again, and an id the edit both adds and removes is not added. An added child goes after the highest stored
    /// order, removed rows included. Throws `ProfileValidationError.noChildren`, writing nothing, when the edit would
    /// leave the family without a child: checked here, where removed rows are seen. All or nothing: the fetches come
    /// between the changes, so the whole body is inside.
    func save(_ edit: FamilyEdit) async throws {
        try modelContext.saveAllOrNothing {
            guard let profile = try record() else { throw ProfileEditError.noProfile }
            if let hasPartner = edit.hasPartner { profile.update(\.hasPartner, to: hasPartner) }

            var stored: [UUID: ChildRecord] = [:]
            for record in try modelContext.fetch(FetchDescriptor<ChildRecord>()) {
                stored[record.childID] = record
            }
            for id in edit.removedIDs {
                // PR 3 marks the row instead.
                if let record = stored[id], !record.isRemoved { modelContext.delete(record) }
            }
            for change in edit.changed where !edit.removedIDs.contains(change.child.id) {
                if let record = stored[change.child.id], !record.isRemoved { record.apply(change) }
            }
            var nextOrder = (stored.values.map(\.order).max() ?? -1) + 1
            for child in edit.added where stored[child.id] == nil && !edit.removedIDs.contains(child.id) {
                let record = ChildRecord(child: child, order: nextOrder, isRemoved: false)
                modelContext.insert(record)
                stored[child.id] = record
                nextOrder += 1
            }
            let kept = stored.values.filter { !$0.isRemoved && !edit.removedIDs.contains($0.childID) }
            guard !kept.isEmpty else { throw ProfileValidationError.noChildren }
        }
    }

    /// Sets only the hero fields the edit names, and only values that differ. Never a child row.
    func save(_ edit: HeroEdit) async throws {
        try modelContext.saveAllOrNothing {
            guard let profile = try record() else { throw ProfileEditError.noProfile }
            profile.apply(edit)
        }
    }

    private func record() throws -> ProfileRecord? {
        try modelContext.fetch(FetchDescriptor<ProfileRecord>()).first
    }
}
