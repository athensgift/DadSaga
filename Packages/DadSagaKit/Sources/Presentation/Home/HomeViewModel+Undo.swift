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
        let visit = departures
        undoOffer = nil
        // Only its own celebration: a moment's may be playing by now.
        withdrawCelebration(id: offer.id)
        isCompleting = true
        defer { isCompleting = false }
        do {
            try await takeBack(offer.eventID)
            if let overview = await load() { refreshOpenSheet(from: overview) }
        } catch {
            // Only on the visit the Undo was tapped on, and only if nothing newer has taken the bar meanwhile.
            if undoOffer == nil, departures == visit {
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

    /// Takes an entry back through its Undo, the bar's or the sheet's. The cards closed in this session for titles the
    /// Undo took are forgotten here, where they are taken, so each comes again when a card reaches its title
    /// (ADR-0055 §3). Nothing else lowers the title he holds, so no load has to look for them.
    func takeBack(_ eventID: UUID) async throws {
        let held = try await useCases.undoRecord.execute(undoing: eventID)
        guard let catalog = overview?.catalog else { return }
        closedTitleCards = closedTitleCards.filter { (catalog.title(id: $0)?.order ?? 0) <= (held?.order ?? -1) }
    }

    /// "Saved · Undo" for what a change recorded; `nil` when it recorded nothing. Nothing else is remembered for it: an
    /// Undo deletes the entry and keeps nothing, so the title is again what the other entries and the store give
    /// (ADR-0055 §3).
    func offerUndo(of change: ProgressChange, id: Int) -> UndoOffer? {
        change.eventID.map { makeUndoOffer(id: id, eventID: $0) }
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
        guard undoOffer?.id == id else { return }
        undoOffer = nil
    }

    /// The dad went to another tab: the bar's Undo is only for what he just recorded, on the screen he recorded it on
    /// (ADR-0021). On the timeline he can delete entries, which keeps the title he holds, the last card's included, so
    /// an Undo waiting here could no longer take that card back whole (ADR-0055 §3). A save or an Undo still running
    /// as he leaves offers none either when it ends (`departures`).
    public func leftForAnotherTab() {
        departures += 1
        undoOffer = nil
    }
}
