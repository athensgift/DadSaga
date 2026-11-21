import Foundation
import Observation
import SwiftUI

/// Which open editors hold changes the dad hasn't saved, so a link from outside the app waits instead of closing them
/// (ADR-0050). One for the whole app: `RootViewModel` owns it, and each `UnsavedChangesGuard` on either tab reports to it
/// through the environment.
///
/// A hold ends at a moment the app controls, never only when SwiftUI happens to free a view:
/// - the editor has nothing left to lose (a save kept it, or the dad undid his change);
/// - the dad discards;
/// - the presentation the editor lives in is dismissed (`end(scope:)`, from the sheet's `onDismiss`).
/// A covering camera or photo viewer ends none of these, so the editor stays held under it.
@MainActor
@Observable
final class UnsavedWork {
    /// Each holding editor and the presentation it lives in.
    private var editors: [UUID: String] = [:]
    /// Runs each time the last hold ends, so a waiting link can go on.
    @ObservationIgnored var onRelease: (@MainActor () -> Void)?

    /// Some editor would lose what the dad changed if it closed now.
    var isHeld: Bool { !editors.isEmpty }

    func set(_ editor: UUID, in scope: String, hasUnsavedChanges: Bool) {
        if hasUnsavedChanges {
            editors[editor] = scope
        } else {
            release { editors.removeValue(forKey: editor) }
        }
    }

    /// The editor is gone, or the dad discarded what it held.
    func closed(_ editor: UUID) {
        release { editors.removeValue(forKey: editor) }
    }

    /// The presentation is dismissed: whatever its editors held is saved or discarded.
    func end(scope: String) {
        release { editors = editors.filter { $0.value != scope } }
    }

    private func release(_ change: () -> Void) {
        let wasHeld = isHeld
        change()
        if wasHeld, !isHeld { onRelease?() }
    }
}

/// Where an editor lives, so dismissing that sheet or screen ends its hold (`UnsavedWork.end(scope:)`).
enum UnsavedScope {
    /// Home's quest, boss or moment sheet.
    static let homeSheet = "home-sheet"
    /// Settings and the pages pushed from it, such as "My family".
    static let settings = "settings"
    /// The timeline's note and photos editor.
    static let timelineJournal = "timeline-journal"
}

extension EnvironmentValues {
    /// The presentation the views below live in (`UnsavedScope`).
    @Entry var unsavedScope = "app"
}

/// One editor's place in `UnsavedWork`. Its `deinit` is only the last resort: a hold normally ends earlier, at one of the
/// moments `UnsavedWork` lists.
@MainActor
final class EditorRegistration {
    private let id = UUID()
    private weak var work: UnsavedWork?

    func report(hasUnsavedChanges: Bool, in scope: String, to work: UnsavedWork?) {
        guard let work else { return }
        self.work = work
        work.set(id, in: scope, hasUnsavedChanges: hasUnsavedChanges)
    }

    /// The dad discarded: nothing is left to lose, even while the sheet is still sliding away.
    func discard() {
        work?.closed(id)
    }

    isolated deinit {
        work?.closed(id)
    }
}
