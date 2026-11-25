import Application
import Domain
import Foundation
import Observation

/// Links from outside the app, such as the home-screen widget (ADR-0023). They only open a screen, never record.
extension HomeViewModel {
    /// Opens a link once nothing would be lost by it (ADR-0050): it waits while something saves or an editor holds
    /// changes the dad hasn't saved, then lets the view close its own sheets, then opens the link.
    /// - Returns: whether the link was opened. `false` when the wait was cancelled, e.g. a newer link replaced this one:
    ///   the caller then leaves it alone, and the newer link's own run opens that one.
    func receive(
        _ pending: PendingLink,
        unsavedWork: UnsavedWork,
        closingOwnSheets: () async -> Void
    ) async -> Bool {
        await waitUntilNothingIsLost(in: unsavedWork)
        guard !Task.isCancelled else { return false }
        await closingOwnSheets()
        guard !Task.isCancelled else { return false }
        await open(pending.link)
        return !Task.isCancelled
    }

    /// Returns at once if nothing is saving and no editor holds changes, else when that becomes true, or when the task
    /// is cancelled.
    private func waitUntilNothingIsLost(in unsavedWork: UnsavedWork) async {
        let busy = Observations { @MainActor [weak self] in
            (self?.isCompleting ?? false) || unsavedWork.isHeld
        }
        for await isBusy in busy where !isBusy {
            return
        }
    }

    /// Shows the link's child, then the quest's sheet or the moment. A child no longer in the family opens home
    /// as it is; a quest that no longer exists or isn't offered to this child (retired, too early, for someone else:
    /// ADR-0053) or a moment that no longer exists opens no sheet.
    /// It reads what its own load returned, and opens only if the screen still shows the link's child: a load started
    /// meanwhile (the app coming back) may hold the previous child, and the dad or a newer link may have picked
    /// another, whose quest this one must not open. A sheet the dad opened meanwhile stays his, for its own child.
    public func open(_ link: AppLink) async {
        dismissSelection()
        selectedChildID = link.childID
        viewedWorldID = nil
        guard let overview = await load(),
              !Task.isCancelled,
              overview.child.id == link.childID,
              selectedChildID == link.childID,
              selectedQuest == nil, selectedBoss == nil, momentCapture == nil else { return }
        switch link {
        case .quest(let id, _):
            // From the whole catalog, not just the shown world: last week's quest may belong to the previous one.
            guard let quest = overview.catalog.quest(id: id),
                  UnlockRules.isOffered(
                      quest, in: overview.catalog, age: overview.adventure.age, family: overview.family
                  ) else { return }
            selectedQuest = detail(for: quest, in: overview)
        case .moment(let eventID, _):
            editMoment(id: eventID, in: overview)
        case .child:
            break
        }
    }
}
