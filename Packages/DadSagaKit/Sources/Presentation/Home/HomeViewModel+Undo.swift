import Application
import Domain
import Foundation
import Localization

/// Undo for a few seconds after the dad records something (ADR-0021).
extension HomeViewModel {
    /// Takes back what was just recorded, as if it never was: any badge, and the title, its card and gear it brought
    /// (ADR-0055 §3). A title card closed since comes again when a card reaches that title again.
    /// While another save is still running the offer stays, so the tap is not lost and can be made again.
    /// If taking it back fails, the entry is still there, so the bar comes back saying so, to try again.
    /// The bar is its only voice: it leaves any sheet open meanwhile, and that sheet's error, as they are.
    public func undoLastRecord() async {
        guard !isCompleting, let offer = undoOffer, let kept = keptBeforeEntries[offer.eventID] else { return }
        undoOffer = nil
        // Only its own celebration: a moment's may be playing by now.
        withdrawCelebration(id: offer.id)
        isCompleting = true
        defer { isCompleting = false }
        do {
            try await takeBack(offer.eventID, restoring: kept)
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
        keptBeforeEntries[eventID] = kept
        return makeUndoOffer(id: id, eventID: eventID)
    }

    /// Undoes an entry and forgets the title cards closed in this session: the store's closed card went back too.
    func takeBack(_ eventID: UUID, restoring kept: KeptStanding) async throws {
        try await useCases.undoRecord.execute(eventID: eventID, restoring: kept)
        keptBeforeEntries[eventID] = nil
        closedTitleCards.removeAll()
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
        keptBeforeEntries[offer.eventID] = nil
    }
}
