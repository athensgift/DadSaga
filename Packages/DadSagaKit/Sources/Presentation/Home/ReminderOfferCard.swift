import DesignSystem
import SwiftUI

/// The calm offer of a weekly reminder at the top of home's cards (ADR-0024). Either button hides it for good.
struct ReminderOfferCard: View {
    let offer: ReminderOffer
    let onAnswer: (_ accept: Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            Label(offer.title, systemImage: "bell")
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
            Text(offer.message)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: DSSpacing.s) {
                Button(offer.accept) { onAnswer(true) }
                    .buttonStyle(.glassProminent)
                Button(offer.decline) { onAnswer(false) }
                    .buttonStyle(.glass)
            }
            .font(DSFont.subheadline)
            .padding(.top, DSSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.m)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
    }
}
