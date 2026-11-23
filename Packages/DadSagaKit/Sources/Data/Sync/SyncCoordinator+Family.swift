import Foundation

/// Why the saga didn't move to a family's zone.
enum FamilyMoveError: Error, Equatable {
    /// iCloud is off for this saga.
    case off
    /// The zone is not a family's.
    case notAFamily
    /// The child map can't be read, or names a child both as one that becomes another and as the family's.
    case unusableChildMap
    /// `saga` names no other family than the one this iPhone syncs with.
    case nothingToFollow
    /// The family `saga` names replaces this iPhone's saga (an import, "which to keep"): the parent is asked in
    /// those words before anything is replaced.
    case replacesTheSaga
}

/// The saga moving between family zones (ADR-0065 §2, §4): into a partner's by a join, after another of the parent's
/// iPhones by a follow, and into a new zone of the parent's own when the partner's sharing ends. The saga store's
/// rows go only where the rejoin's rule says so; a zone that goes never deletes any.
extension SyncCoordinator {
    /// The parent joins the family in `zone`, or joins it again (ADR-0065 §2). `childMap` says which of their
    /// children is which of the family's; none for a rejoin, where the same id is the same child. What the iPhone has
    /// merges into the zone once it has been fetched whole; then `saga` names the family, and the parent's own family
    /// zone is deleted.
    func join(_ zone: SyncZone, childMap: ChildMap) async throws {
        try await onChain { try await self.attach(zone, childMap, writingSaga: true) }
    }

    /// Another of the parent's iPhones moved the saga to the family `saga` names, and the parent said to follow
    /// (ADR-0065 §4): `saga`'s child map is applied here as it was there, and what this iPhone has merges into the
    /// zone. This iPhone writes no `saga` and deletes no zone: the other one did.
    func follow() async throws {
        try await onChain {
            guard let family = try await self.ledgerWhileOn()?.settings().follow else { throw FamilyMoveError.nothingToFollow }
            guard family.merges else { throw FamilyMoveError.replacesTheSaga }
            var map = ChildMap()
            if let json = family.childMap {
                guard let read = ChildMap(json: json) else { throw FamilyMoveError.unusableChildMap }
                map = read
            }
            try await self.attach(family.zone, map, writingSaga: false)
        }
    }

    /// The family's zone is `zone` from now on. Its engine starts from nothing, so its first fetch brings the zone
    /// whole; until that ends, nothing of the family is sent.
    private func attach(_ zone: SyncZone, _ map: ChildMap, writingSaga: Bool) async throws {
        guard let ledger = try await ledgerWhileOn() else { throw FamilyMoveError.off }
        guard case .family(let id, let owner) = zone else { throw FamilyMoveError.notAFamily }
        guard !map.isChained else { throw FamilyMoveError.unusableChildMap }
        // What the dad changed up to now waits with the rest, and merges into the new zone.
        try await drain(ledger)
        try await ledger.attach(family: (id, owner), map: map, writingSaga: writingSaga)
        let settings = try await ledger.settings()
        forgetEngine(.shared)
        if settings.database(for: .family) == .private { forgetEngine(.private) }
        try await makeEngines(ledger, settings)
        try await give(ledger)
    }

    /// The family's zone has been fetched whole (ADR-0065 §2, "A full send with no change token"). A child map that
    /// still waits is applied for the family's children that came; then every row the zone lacks is sent, or deleted
    /// here when it is a current member's deletion, and the family's changes wait no longer.
    func fullSend(_ ledger: SyncLedger) async throws {
        let settings = try await ledger.settings()
        guard let account = settings.account else { return }
        let applier = try await saga.open().applier
        if settings.childMapWaits, let map = settings.childMap {
            let applied = try await applier.apply(map)
            try await ledger.mapped(applied)
            try await renameOffers(by: applied, ledger)
        }
        let plan = try await applier.fullSendPlan(FullSendContext(
            held: try await ledger.heldNames(.family), members: try await ledger.members(), account: account,
            gone: try await ledger.goneIDs()
        ))
        try await ledger.fullSend(plan.send, writingAgain: plan.writeAgain)
        for photoID in plan.photosToDelete { await photos.delete(id: photoID) }
    }

    /// The family's zone in the partner's iCloud is gone: they stopped sharing (ADR-0065 §4). This parent keeps
    /// everything, every author's entries, in a new family zone of their own, with only their own member and the
    /// markers of the children deleted for good. When another of their iPhones has made that zone already, `saga`
    /// names it, and this iPhone waits to follow instead of making a second one.
    func familyLeft(_ ledger: SyncLedger) async throws {
        guard try await ledger.settings().database(for: .family) == .shared else { return }
        if try await sagaNamesAnotherFamily(ledger) { return }
        try await ledger.rebuild(family: UUID(), sending: try await everyRecord(in: .family, ledger))
        forgetEngine(.shared)
        if let zone = try await ledger.settings().familyZone { await engines[.private]?.add([.save(zone)]) }
        try await give(ledger)
    }

    /// What a join or a rebuild leaves for when the family's zone holds everything that waited (ADR-0065 §4): `saga`
    /// names the family then. Only once `saga` is saved is the parent's own zone that a join left deleted, so their
    /// other iPhones learn where the saga went before they see its old zone go.
    func endMove(_ ledger: SyncLedger) async throws {
        if try await ledger.familySent() { try await give(ledger) }
        let settings = try await ledger.settings()
        guard let old = settings.oldFamilyZoneID, let account = settings.account, settings.pause != .signedOut,
              !settings.sagaWaitsForFamily, settings.follow == nil,
              try await !ledger.pending(.personal).contains(where: { $0.name == .saga }) else { return }
        await engines[.private]?.add([.delete(.family(old, owner: account))])
    }
}
