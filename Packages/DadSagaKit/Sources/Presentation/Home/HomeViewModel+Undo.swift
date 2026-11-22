import Application
import Domain
import Foundation
import Localization

/// Undo for a few seconds after the dad records something (ADR-0021).
extension HomeViewModel {
    /// Takes back what was just recorded, as if it never was: any badge, and the title, its level and the gear it
    /// brought (ADR-0055 §3). While another save is still running the offer stays, so the tap is not lost and can be
    /// made again. If taking it back fails, the entry is still there, so the bar comes back saying so, to try again.
    /// The bar is its only voice: it leaves any sheet open meanwhile, and that sheet's error, as they are.
    public func undoLastRecord() async {
        guard !isCompleting, let offer = undoOffer else { return }
        undoOffer = nil
        // Only its own celebration: a moment's may be playing by now.
        withdrawCelebration(id: offer.id)
        isCompleting = true
        defer { isCompleting = false }
        do {
            try await takeBack(offer.eventID)
            if let overview = await load() { refreshOpenSheet(from: overview) }
        } catch {
            // Only if nothing newer has taken the bar meanwhile.
            if undoOffer == nil {
                undoOffer = makeUndoOffer(id: offer.id, eventID: offer.eventID, didFail: true)
            }
        }
    }

    /// A quest or boss sheet open meanwhile shows the last note: after an undo that may be gone.
    private func refreshOpenSheet(from overview: HomeOverview) {
        if let open = selectedQuest, let quest = overview.catalog.quest(id: open.id) {
            selectedQuest = detail(for: quest, in: overview)
        }
        if let open = selectedBoss, let boss = overview.catalog.boss(id: open.id) {
            selectedBoss = detail(for: boss)
        }
    }

    /// "Saved · Undo" for what a change recorded, remembering what to put back; `nil` when it recorded nothing.
    func offerUndo(of change: ProgressChange, id: Int) -> UndoOffer? {
        guard let eventID = change.eventID, let kept = change.keptBefore else { return nil }
        undoable.append(UndoableEntry(eventID: eventID, keptBefore: kept))
        return makeUndoOffer(id: id, eventID: eventID)
    }

    /// Whether the entry's Undo is still on screen.
    func canUndo(_ eventID: UUID) -> Bool {
        undoable.contains { $0.eventID == eventID }
    }

    /// Takes the entry back. Home and a moment's sheet can each offer an Undo at once, and either may go first: an entry
    /// recorded after this one now goes back to what was kept before this one, which no longer holds anything this one
    /// gave.
    func takeBack(_ eventID: UUID) async throws {
        guard let index = undoable.firstIndex(where: { $0.eventID == eventID }) else { return }
        let kept = undoable[index].keptBefore
        try await useCases.undoRecord.execute(eventID: eventID, restoring: kept)
        undoable.remove(at: index)
        for later in undoable.indices where later >= index {
            undoable[later].keptBefore = kept
        }
    }

    /// An Undo off the screen: its time ran out, or a newer one or the sheet's closing took its place.
    func forgetUndo(of offer: UndoOffer) {
        undoable.removeAll { $0.eventID == offer.eventID }
    }

    func makeUndoOffer(id: Int, eventID: UUID, didFail: Bool = false) -> UndoOffer {
        UndoOffer(
            id: id,
            eventID: eventID,
            message: didFail ? strings.text("Couldn't undo. Please try again.") : strings.text("Saved"),
            actionTitle: strings.text("Undo"),
            didFail: didFail
        )
    }

    /// The offer's time is up. Ignored if a newer offer has replaced it.
    public func undoOfferExpired(id: Int) {
        guard let offer = undoOffer, offer.id == id else { return }
        undoOffer = nil
        forgetUndo(of: offer)
    }
}

/// An entry whose Undo is on screen, and what the store kept just before it.
struct UndoableEntry {
    let eventID: UUID
    var keptBefore: KeptStanding
}
