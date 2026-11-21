import DesignSystem
import SwiftUI

/// The error under a screen's or a sheet's content, when saving failed. Shown in place: an alert from the screen below
/// would wait until the sheet closed. VoiceOver reads it out as it appears, since the dad may not be looking at it.
struct SheetError: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.boss)
                .onChange(of: message, initial: true) { _, new in AccessibilityNotification.Announcement(new).post() }
        }
    }
}
