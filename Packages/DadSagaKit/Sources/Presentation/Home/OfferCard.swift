import DesignSystem
import SwiftUI

/// A calm offer at the top of home's cards: the weekly reminder (ADR-0024) or a saga film (ADR-0037 §5). Home shows
/// one at a time, and either button hides it for good.
struct OfferCard: View {
    let symbol: String
    let title: String
    /// What the offer is about, e.g. "Άννα · 2ος χρόνος".
    var detail: String?
    let message: String
    let accept: String
    let decline: String
    let onAnswer: (_ accept: Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            Label(title, systemImage: symbol)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
            if let detail {
                Text(detail)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(message)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: DSSpacing.s) {
                Button(accept) { onAnswer(true) }
                    .buttonStyle(.glassProminent)
                    .onTintLabel()
                Button(decline) { onAnswer(false) }
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

extension OfferCard {
    init(_ offer: ReminderOffer, onAnswer: @escaping (_ accept: Bool) -> Void) {
        self.init(
            symbol: "bell", title: offer.title, message: offer.message, accept: offer.accept, decline: offer.decline,
            onAnswer: onAnswer
        )
    }

    init(_ offer: SagaFilmOffer, onAnswer: @escaping (_ accept: Bool) -> Void) {
        self.init(
            symbol: "film", title: offer.title, detail: offer.childLine, message: offer.message, accept: offer.accept,
            decline: offer.decline, onAnswer: onAnswer
        )
    }
}
