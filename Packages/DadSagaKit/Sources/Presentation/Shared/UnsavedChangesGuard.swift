import SwiftUI

/// Keeps a sheet or screen from losing what the dad changed and hasn't saved: while there is something to lose, a swipe
/// can't close it, and Close asks first. The question is an alert, so every answer is a visible button: discard, keep
/// editing, and save where saving only keeps his edit (ADR-0042 §5, ADR-0050). It also tells the app's `UnsavedWork`,
/// for as long as the editor exists, so a link from outside waits for it.
struct UnsavedChangesGuard: ViewModifier {
    let hasUnsavedChanges: Bool
    @Binding var isAsking: Bool
    let labels: JournalLabels
    /// `false` while photos are still arriving: Save would leave them out.
    var canSave = true
    /// `nil` where saving would record something new, with its XP: a quest or a boss. Only the dad's own button does
    /// that (ADR-0006), so the question then offers only to discard or keep editing.
    let onSave: (() -> Void)?
    let onDiscard: () -> Void
    @Environment(UnsavedWork.self) private var unsavedWork: UnsavedWork?
    @State private var registration = EditorRegistration()

    func body(content: Content) -> some View {
        content
            .interactiveDismissDisabled(hasUnsavedChanges)
            .alert(labels.discardQuestion, isPresented: $isAsking) {
                if let onSave {
                    Button(labels.save, action: onSave)
                        .disabled(!canSave)
                }
                Button(labels.discard, role: .destructive, action: onDiscard)
                Button(labels.keepEditing, role: .cancel) {}
            }
            .onChange(of: hasUnsavedChanges, initial: true) { _, held in
                registration.report(hasUnsavedChanges: held, to: unsavedWork)
            }
    }
}
