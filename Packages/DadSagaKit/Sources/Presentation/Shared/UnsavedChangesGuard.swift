import SwiftUI

/// Keeps a sheet from losing what the dad changed and hasn't saved: while there is something to lose, a swipe can't
/// close it, and Close asks first, offering to save it, to discard it or to keep editing (ADR-0042 §5).
struct UnsavedChangesGuard: ViewModifier {
    let hasUnsavedChanges: Bool
    @Binding var isAsking: Bool
    let labels: JournalLabels
    /// `false` while photos are still arriving: Save would leave them out.
    let canSave: Bool
    let onSave: () -> Void
    let onDiscard: () -> Void

    func body(content: Content) -> some View {
        content
            .interactiveDismissDisabled(hasUnsavedChanges)
            .confirmationDialog(labels.discardQuestion, isPresented: $isAsking, titleVisibility: .visible) {
                if canSave {
                    Button(labels.save, action: onSave)
                }
                Button(labels.discard, role: .destructive, action: onDiscard)
                Button(labels.keepEditing, role: .cancel) {}
            }
    }
}
