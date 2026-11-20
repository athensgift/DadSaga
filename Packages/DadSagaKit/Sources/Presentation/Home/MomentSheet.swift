import DesignSystem
import SwiftUI

/// A legendary moment's sheet: step 1 to choose the first and when, step 2 for photos and a few words (ADR-0042 §5).
/// One sheet for both, so moving on never closes and reopens it.
struct MomentSheet: View {
    let capture: MomentCapture
    let errorMessage: String?
    let isSaving: Bool
    let loader: PhotoLoader
    let actions: Actions

    /// What the sheet asks home to do.
    struct Actions {
        let onCapture: (_ firstID: String, _ date: Date) -> Void
        let onSave: (_ date: Date, _ note: String, _ photos: PhotoDrafts) -> Void
        let onDelete: () -> Void
        let onUndoExpired: (_ id: Int) -> Void
        let onClose: () -> Void
    }

    var body: some View {
        NavigationStack {
            switch capture.step {
            case .choose(let choice):
                MomentChoiceStep(
                    title: capture.title,
                    choice: choice,
                    errorMessage: errorMessage,
                    isSaving: isSaving,
                    onCapture: actions.onCapture,
                    onClose: actions.onClose
                )
            case .details(let details):
                MomentDetailsStep(
                    details: details,
                    errorMessage: errorMessage,
                    isSaving: isSaving,
                    loader: loader,
                    actions: actions
                )
                // A moment's own fields, never another's.
                .id(details.momentID)
            }
        }
    }
}

/// The error under a sheet's content, when saving failed.
struct SheetError: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.boss)
        }
    }
}
