import Foundation
import SwiftData

/// What the applier is told to plan a full send.
struct FullSendContext: Sendable {
    /// The family's records the zone holds, as its whole fetch showed.
    let held: Set<RecordName>
    /// The family's members: each parent's profile id, and their account.
    let members: [UUID: String]
    /// This parent's account.
    let account: String
    /// The children deleted for good that `Sync.store` knows.
    let gone: Set<UUID>
}

/// What a full send leaves for the coordinator to do.
struct FullSendPlan: Hashable, Sendable {
    /// The records the zone lacks, to send whole: members, children, entries, then photos.
    var send: [RecordName] = []
    /// Records to delete and then write: this parent's member, when the zone's was created by another account.
    var writeAgain: [RecordName] = []
    /// The photos of entries that went here, that no entry lists any more: their files go.
    var photosToDelete: [String] = []
    /// Whether a row changed: the widget reloads on it.
    var changedSomething = false
}

extension SwiftDataSyncApplier {
    /// The rejoin's rule (ADR-0065 §2), once the family's zone has been fetched whole: a row the zone holds has merged
    /// as it came, and this decides the rest. No row stays on this iPhone only, since a later full send would upload
    /// it anyway and no one could delete it:
    /// - this parent's member is sent, or written again when another account created the one the zone holds;
    /// - a child the zone lacks is sent, and so is the marker of each child deleted for good;
    /// - an entry the zone lacks is sent when it is this parent's; deleted here, under `sync`, when its author is
    ///   another current member, since it is their deletion; and sent as it is for any other author;
    /// - the photos of the entries that stay are sent.
    /// One turn, so it decides on the rows as they are.
    func fullSendPlan(_ context: FullSendContext) throws -> FullSendPlan {
        guard let profile = try modelContext.fetch(FetchDescriptor<ProfileRecord>()).first else { return FullSendPlan() }
        var plan = FullSendPlan()
        let (own, member) = (profile.profileID, RecordName.member(profile.profileID))
        if !context.held.contains(member) {
            plan.send.append(member)
        } else if context.members[own] != context.account {
            plan.writeAgain.append(member)
        }
        let children = try modelContext.fetch(FetchDescriptor<ChildRecord>()).map(\.childID).filter { !context.gone.contains($0) }
        plan.send += (children + context.gone.sorted { $0.uuidString < $1.uuidString }).map(RecordName.child)
        var deleted: [ProgressEventRecord] = []
        var photoIDs: [String] = []
        for entry in try modelContext.fetch(FetchDescriptor<ProgressEventRecord>()) {
            let isTheirDeletion = entry.authorID != own && context.members[entry.authorID] != nil
            if !context.held.contains(entry.recordName), isTheirDeletion {
                deleted.append(entry)
            } else {
                plan.send.append(entry.recordName)
                photoIDs += entry.photoIDs
            }
        }
        plan.send += photoIDs.map(RecordName.photo)
        plan.send.removeAll(where: context.held.contains)
        guard !deleted.isEmpty else { return plan }
        let photosOfDeleted = deleted.flatMap(\.photoIDs)
        try modelContext.saveAllOrNothing(as: .sync) {
            for entry in deleted { modelContext.delete(entry) }
        }
        plan.photosToDelete = try unlisted(photosOfDeleted)
        plan.changedSomething = true
        return plan
    }
}
