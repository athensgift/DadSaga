import DesignSystem
import SwiftUI

/// The error when saving failed, beside the button that saves: under a screen's or a sheet's content, or pinned with a
/// pinned button (`pinnedSheetError`). Shown in place: an alert from the screen below
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

extension View {
    /// `SheetError` under the navigation bar, for a long screen whose button that saves is in that bar: in the content it
    /// could be scrolled out of the dad's sight.
    func pinnedSheetError(_ message: String?) -> some View {
        safeAreaBar(edge: .top) {
            SheetError(message: message)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DSSpacing.m)
                .padding(.bottom, message == nil ? 0 : DSSpacing.s)
        }
    }
}
