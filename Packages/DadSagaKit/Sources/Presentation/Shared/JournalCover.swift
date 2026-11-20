import DesignSystem
import SwiftUI

/// An entry's cover photo, whole; a tap opens it full screen. Drawn at the top of the photos field, or above the
/// fold of a half-open iPhone Duo (ADR-0043).
struct JournalCover: View {
    let source: PhotoSource
    let loader: PhotoLoader
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            WholePhoto(source: source, loader: loader)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        // The cover's square says the same and carries the actions: VoiceOver reads the cover once.
        .accessibilityHidden(true)
    }
}
