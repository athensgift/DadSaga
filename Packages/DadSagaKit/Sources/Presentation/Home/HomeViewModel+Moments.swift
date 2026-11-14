import Application
import Foundation

/// Legendary moments: capture a first for the selected child, or correct one captured earlier.
extension HomeViewModel {
    public func startCapture() {
        guard let snapshot else { return }
        errorMessage = nil
        momentCapture = momentsFormatter.capture(
            for: snapshot.child,
            catalog: snapshot.catalog,
            progress: snapshot.progress,
            now: now()
        )
    }

    /// Opens a captured moment to change its date, note or photo, or to delete it.
    public func editMoment(id: UUID) {
        guard let snapshot,
              let moment = snapshot.progress.moments(for: snapshot.child.id).first(where: { $0.eventID == id }) else { return }
        errorMessage = nil
        momentCapture = momentsFormatter.edit(moment, for: snapshot.child, now: now())
    }

    public func dismissCapture() {
        momentCapture = nil
        errorMessage = nil
    }

    /// Saves the open sheet: a new moment (with XP and a celebration) or changes to an existing one.
    public func saveMoment(firstID: String, date: Date, note: String, photo: MomentPhotoEdit = .keep) async {
        guard let capture = momentCapture, let childID = selectedChildID else { return }
        if let editing = capture.editing {
            await perform {
                try await self.useCases.moments.update.execute(
                    momentID: editing.momentID,
                    happenedOn: date,
                    note: note,
                    photo: photo.change,
                    now: self.now()
                )
            }
        } else if let option = capture.options.first(where: { $0.id == firstID }) {
            let request = CaptureMomentRequest(
                firstID: firstID,
                childID: childID,
                date: date,
                note: note,
                photo: photo.newData
            )
            await record(badge: nil, moment: "\(option.emoji) \(option.title)") {
                try await self.useCases.moments.capture.execute(request, now: self.now())
            }
        }
    }

    /// Deletes the moment being edited, with its photo and XP.
    public func deleteMoment() async {
        guard let editing = momentCapture?.editing else { return }
        await perform {
            try await self.useCases.moments.delete.execute(momentID: editing.momentID)
        }
    }

    /// Image data for a moment's photo, or `nil` if it is gone.
    public func photoData(id: String) async -> Data? {
        await useCases.moments.getPhoto.execute(id: id)
    }

    /// Runs a change that earns nothing: closes the sheet and refreshes, or shows an error and keeps it open.
    private func perform(_ action: () async throws -> Void) async {
        guard !isCompleting else { return }
        isCompleting = true
        defer { isCompleting = false }
        do {
            try await action()
            momentCapture = nil
            errorMessage = nil
            await reload()
        } catch {
            errorMessage = saveFailedMessage
        }
    }
}

private extension MomentPhotoEdit {
    var change: PhotoChange {
        switch self {
        case .keep: .keep
        case .remove: .remove
        case .replace(let data): .replace(data)
        }
    }

    /// For a new moment: the photo to store, if one was chosen.
    var newData: Data? {
        if case .replace(let data) = self { data } else { nil }
    }
}
