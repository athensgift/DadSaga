import Foundation
import Observation

/// Which open editors hold changes the dad hasn't saved, so a link from outside the app can wait instead of closing
/// them (`HomeViewModel.receive`, ADR-0050). One for the whole app: the root screen owns it, and each
/// `UnsavedChangesGuard` on either tab reports to it through the environment.
@MainActor
@Observable
final class UnsavedWork {
    private var editors: Set<UUID> = []

    /// Some editor would lose what the dad changed if it closed now.
    var isHeld: Bool { !editors.isEmpty }

    func set(_ editor: UUID, hasUnsavedChanges: Bool) {
        if hasUnsavedChanges { editors.insert(editor) } else { editors.remove(editor) }
    }

    /// The editor is gone: whatever it held is discarded or saved.
    func closed(_ editor: UUID) {
        editors.remove(editor)
    }
}

/// One editor's place in `UnsavedWork`, for as long as the editor exists. It ends when the editor's view is gone for
/// good (its sheet or screen dismissed), not when something covers it: the camera and the photo viewer present full
/// screen over the editor, which makes SwiftUI call `onDisappear` on it although its words are still there.
@MainActor
final class EditorRegistration {
    private let id = UUID()
    private weak var work: UnsavedWork?

    func report(hasUnsavedChanges: Bool, to work: UnsavedWork?) {
        guard let work else { return }
        self.work = work
        work.set(id, hasUnsavedChanges: hasUnsavedChanges)
    }

    isolated deinit {
        work?.closed(id)
    }
}
