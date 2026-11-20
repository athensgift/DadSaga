import DesignSystem
import SwiftUI

/// The error under a sheet's content, when saving failed. Shown in the sheet: an alert from the screen below would
/// wait until the sheet closed.
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
