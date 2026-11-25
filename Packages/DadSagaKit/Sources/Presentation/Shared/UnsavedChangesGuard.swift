import SwiftUI

/// Keeps a sheet or screen from losing what the dad changed and hasn't saved: while there is something to lose, a swipe
/// can't close it, and Close asks first. The question is an alert, so every answer is a visible button: discard, keep
/// editing, and save where saving only keeps his edit (ADR-0042 §5, ADR-0050). A swipe can't close it while a save is
/// under way either; each sheet disables its own Close button then (ADR-0055 §3). It also tells the app's
/// `UnsavedWork` while there is something to lose or a save is under way, so a link from outside waits for it.
struct UnsavedChangesGuard: ViewModifier {
    let hasUnsavedChanges: Bool
    @Binding var isAsking: Bool
    let labels: JournalLabels
    /// `false` while photos are still arriving: Save would leave them out.
    var canSave = true
    /// A save under way can't be discarded: it writes everything anyway, so the sheet stays until it ends.
    var isSaving = false
    /// `nil` where saving would record something new, with its XP: a quest or a boss. Only the dad's own button does
    /// that (ADR-0006), so the question then offers only to discard or keep editing.
    let onSave: (() -> Void)?
    let onDiscard: () -> Void
    @Environment(UnsavedWork.self) private var unsavedWork: UnsavedWork?
    @Environment(\.unsavedScope) private var scope
    /// Made the first time there is something to report, not on every redraw.
    @State private var registration: EditorRegistration?

    func body(content: Content) -> some View {
        content
            .interactiveDismissDisabled(hasUnsavedChanges || isSaving)
            .alert(labels.discardQuestion, isPresented: $isAsking) {
                if let onSave {
                    Button(labels.save, action: onSave)
                        .disabled(!canSave)
                }
                Button(labels.discard, role: .destructive) {
                    registration?.discard()
                    onDiscard()
                }
                Button(labels.keepEditing, role: .cancel) {}
            }
            .onChange(of: hasUnsavedChanges || isSaving, initial: true) { _, held in
                guard held || registration != nil else { return }
                let registration = registration ?? EditorRegistration()
                self.registration = registration
                registration.report(hasUnsavedChanges: held, in: scope, to: unsavedWork)
            }
    }
}
