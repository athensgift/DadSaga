import SwiftUI

/// Keeps a sheet or screen from losing what the dad changed and hasn't saved: while there is something to lose, a swipe
/// can't close it, and Close asks first, offering to discard it or to keep editing, and to save it where saving only
/// keeps his edit (ADR-0042 §5, ADR-0050). It also tells home's `UnsavedWork`, so a link from outside waits for it.
struct UnsavedChangesGuard: ViewModifier {
    let hasUnsavedChanges: Bool
    @Binding var isAsking: Bool
    let labels: JournalLabels
    /// `false` while photos are still arriving: Save would leave them out.
    let canSave: Bool
    /// `nil` where saving would record something new, with its XP: a quest or a boss. Only the dad's own button does
    /// that (ADR-0006), so the question then offers only to discard or keep editing.
    let onSave: (() -> Void)?
    let onDiscard: () -> Void
    @Environment(UnsavedWork.self) private var unsavedWork: UnsavedWork?
    @State private var editor = UUID()

    func body(content: Content) -> some View {
        content
            .interactiveDismissDisabled(hasUnsavedChanges)
            .confirmationDialog(labels.discardQuestion, isPresented: $isAsking, titleVisibility: .visible) {
                if canSave, let onSave {
                    Button(labels.save, action: onSave)
                }
                Button(labels.discard, role: .destructive, action: onDiscard)
                Button(labels.keepEditing, role: .cancel) {}
            }
            .onChange(of: hasUnsavedChanges, initial: true) { _, held in
                unsavedWork?.set(editor, hasUnsavedChanges: held)
            }
            .onDisappear { unsavedWork?.closed(editor) }
    }
}
