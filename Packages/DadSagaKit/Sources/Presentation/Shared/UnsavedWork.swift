import Foundation
import Observation

/// Which open editors hold changes the dad hasn't saved, so a link from outside the app can wait instead of closing
/// them (`HomeView.openPendingLink`). Each `UnsavedChangesGuard` below home reports to it through the environment.
@MainActor
@Observable
final class UnsavedWork {
    private var editors: Set<UUID> = []

    /// Some editor would lose what the dad changed if it closed now.
    var isHeld: Bool { !editors.isEmpty }

    func set(_ editor: UUID, hasUnsavedChanges: Bool) {
        if hasUnsavedChanges { editors.insert(editor) } else { editors.remove(editor) }
    }

    /// The editor closed: whatever it held is gone or saved.
    func closed(_ editor: UUID) {
        editors.remove(editor)
    }
}
