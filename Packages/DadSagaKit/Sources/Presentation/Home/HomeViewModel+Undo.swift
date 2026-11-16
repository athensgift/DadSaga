import Foundation

/// Undo for a few seconds after the dad records something (ADR-0021).
extension HomeViewModel {
    /// Takes back what was just recorded: its XP, and any level, gear or badge it brought.
    public func undoLastRecord() async {
        guard let offer = undoOffer else { return }
        undoOffer = nil
        celebrationFinished()
        await perform {
            try await self.useCases.deleteEvent.execute(eventID: offer.eventID)
        }
    }

    func makeUndoOffer(id: Int, eventID: UUID) -> UndoOffer {
        UndoOffer(
            id: id,
            eventID: eventID,
            message: strings.text(el: "Καταγράφηκε", en: "Saved"),
            actionTitle: strings.text(el: "Αναίρεση", en: "Undo")
        )
    }

    /// The offer's time is up. Ignored if a newer offer has replaced it.
    public func undoOfferExpired(id: Int) {
        if undoOffer?.id == id { undoOffer = nil }
    }
}
