import Application
import Foundation
import Localization

/// Undo for a few seconds after the dad records something (ADR-0021).
extension HomeViewModel {
    /// Takes back what was just recorded, and any badge it brought. The title and gear stay (ADR-0055 §3).
    /// While another save is still running the offer stays, so the tap is not lost and can be made again.
    /// If taking it back fails, the entry is still there, so the bar comes back saying so, to try again.
    /// The bar is its only voice: it leaves any sheet open meanwhile, and that sheet's error, as they are.
    public func undoLastRecord() async {
        guard !isCompleting, let offer = undoOffer else { return }
        undoOffer = nil
        // Only its own celebration: a moment's may be playing by now.
        celebrationFinished(id: offer.id)
        isCompleting = true
        defer { isCompleting = false }
        do {
            try await useCases.deleteEvent.execute(eventID: offer.eventID)
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
        if undoOffer?.id == id { undoOffer = nil }
    }
}
