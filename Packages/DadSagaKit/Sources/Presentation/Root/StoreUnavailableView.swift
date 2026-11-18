import DesignSystem
import SwiftUI

/// Shown when the saved saga cannot be read (ADR-0026). Calm, no blame, and nothing here can delete anything.
struct StoreUnavailableView: View {
    let content: StoreUnavailableContent
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(content.title, systemImage: "book.closed")
                .font(DSFont.title)
                .foregroundStyle(DSColor.textPrimary)
        } description: {
            Text(content.message)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
        } actions: {
            PrimaryButton(content.retryTitle, action: onRetry)
                .padding(.horizontal, DSSpacing.l)
        }
    }
}
