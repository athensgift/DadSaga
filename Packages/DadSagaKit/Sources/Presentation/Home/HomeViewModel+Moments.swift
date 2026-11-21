import Application
import Foundation

/// Legendary moments, in two steps (ADR-0042 §5): choosing the first records it; photos and a few words follow, if
/// the dad likes. Editing a moment opens straight at the second step.
extension HomeViewModel {
    /// Opens step 1 for the selected child.
    public func startCapture() {
        guard let overview else { return }
        errorMessage = nil
        momentCapture = momentsFormatter.capture(
            for: overview.child,
            catalog: overview.catalog,
            progress: overview.progress,
            now: now()
        )
    }

    /// Step 1's ✓: records the first at once, with its XP, then moves the same sheet on to step 2 with "Saved · Undo"
    /// in it. The celebration waits for the sheet to close, so the dad sees it on home. On failure step 1 stays, with
    /// an error.
    public func captureMoment(firstID: String, date: Date) async {
        guard let capture = momentCapture, case .choose(let choice) = capture.step, let child = overview?.child,
              let option = choice.options.first(where: { $0.id == firstID }) else { return }
        let request = CaptureMomentRequest(firstID: firstID, childID: child.id, date: date)
        guard let change = await record({ try await self.useCases.moments.capture.execute(request, now: self.now()) }),
              let eventID = change.eventID,
              // Closed, or closed and opened again, while it saved: the moment is kept, the sheet left as it is now.
              momentCapture?.id == capture.id else { return }
        // Read from the change itself, not the reloaded screen: the moment is saved even if home failed to reload.
        guard let moment = change.after.moments(for: child.id).first(where: { $0.eventID == eventID }) else {
            momentCapture = nil
            return
        }
        let celebration = makeCelebration(change, moment: "\(option.emoji) \(option.title)")
        pendingMomentCelebration = celebration
        momentCapture?.step = .details(momentsFormatter.details(
            moment,
            for: child,
            now: now(),
            isNew: true,
            undoOffer: makeUndoOffer(id: celebration.id, eventID: eventID)
        ))
    }

    /// Opens a captured moment at step 2, to change its date, note or photos, or to delete it. No celebration.
    public func editMoment(id: UUID) {
        editMoment(id: id, in: overview)
    }

    /// - Parameter overview: what to find the moment in, e.g. what a link's own load read.
    func editMoment(id: UUID, in overview: HomeOverview?) {
        guard let overview,
              let moment = overview.progress.moments(for: overview.child.id).first(where: { $0.eventID == id }) else { return }
        errorMessage = nil
        let details = momentsFormatter.details(moment, for: overview.child, now: now(), isNew: false)
        momentCapture = MomentCapture(id: UUID(), title: overview.child.name, step: .details(details))
    }

    /// Step 2's Save: the moment's date, note and photos as the dad left them. Closes the sheet.
    public func saveMomentDetails(date: Date, note: String, photos: PhotoDrafts) async {
        guard let details = momentCapture?.details else { return }
        await perform {
            try await self.useCases.moments.update.execute(
                momentID: details.momentID,
                happenedOn: date,
                note: note,
                photos: photos.entryPhotos,
                now: self.now()
            )
        }
    }

    /// Deletes the moment in step 2, with its photos and XP, and closes the sheet: Delete when editing, Undo when new.
    public func deleteMoment() async {
        guard let details = momentCapture?.details else { return }
        await perform {
            try await self.useCases.deleteEvent.execute(eventID: details.momentID)
            // Undone: nothing to celebrate.
            self.pendingMomentCelebration = nil
        }
    }

    /// A sheet has finished closing. A moment just recorded celebrates now, on home, where the dad can see it,
    /// however its sheet was closed: Save, Not now, Close or a link from outside.
    public func sheetDismissed() {
        // Only with home in sight: a link may have opened another sheet in the moment's place.
        guard selectedQuest == nil, selectedBoss == nil, momentCapture == nil,
              let pending = pendingMomentCelebration else { return }
        pendingMomentCelebration = nil
        celebration = pending
    }

    /// The undo offer in step 2 ran out. Ignored if it is not the one shown.
    public func momentUndoExpired(id: Int) {
        guard var details = momentCapture?.details, details.undoOffer?.id == id else { return }
        details.undoOffer = nil
        momentCapture?.step = .details(details)
    }

    /// Image data for a stored photo, or `nil` if it is gone.
    public func photoData(id: String, maxPixelSize: Int) async -> Data? {
        await useCases.moments.getPhoto.execute(id: id, maxPixelSize: maxPixelSize)
    }

    /// Runs a change to the open moment that earns nothing: closes its sheet and refreshes, or shows an error and keeps
    /// it open. A link from outside waits while it runs (`HomeView.openPendingLink`), so the sheet is still the moment's.
    func perform(_ action: () async throws -> Void) async {
        guard !isCompleting else { return }
        isCompleting = true
        defer { isCompleting = false }
        errorMessage = nil
        do {
            try await action()
            momentCapture = nil
            await load()
        } catch {
            errorMessage = saveFailedMessage
        }
    }
}
