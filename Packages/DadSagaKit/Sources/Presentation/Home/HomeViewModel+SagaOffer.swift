import Application
import Domain
import Foundation
import Localization

/// The one calm offer of a saga film on home, for a birthday or a world the child has grown out of (ADR-0036 §7,
/// ADR-0037 §5). No word about time, no count and no badge: it shows until the dad answers it or it quietly goes.
public struct SagaFilmOffer: Equatable, Sendable {
    public let title: String
    /// Whose film and of what, e.g. "Άννα · 2ος χρόνος".
    public let childLine: String
    public let message: String
    public let accept: String
    public let decline: String
    /// The occasion the answer is remembered for.
    let occasionID: String
    /// The film "Make the film" opens.
    let request: SagaFilmRequest
}

extension HomeViewModel {
    /// The offer for the occasion home's query found, unless the dad has just answered it.
    func makeSagaOffer(_ overview: HomeOverview) -> SagaFilmOffer? {
        guard let occasion = overview.sagaOffer, !answeredSagaOffers.contains(occasion.id),
              let child = overview.profile.children.first(where: { $0.id == occasion.childID })
        else { return nil }
        let period = SagaFilmTexts(locale: locale).periodTitle(occasion.period, catalog: overview.catalog)
        return SagaFilmOffer(
            title: strings.text("A short film?"),
            childLine: "\(child.name) · \(period)",
            message: strings.text("Your photos, firsts and notes from it, as a film with music. Made on this iPhone."),
            accept: strings.text("Make the film"),
            decline: strings.text("Not now"),
            occasionID: occasion.id,
            request: SagaFilmRequest(childID: child.id, period: occasion.period)
        )
    }

    /// Either answer closes the card for good: this occasion is never offered again (ADR-0006). "Make the film" also
    /// returns the film to open.
    public func answerSagaOffer(accept: Bool) async -> SagaFilmRequest? {
        guard let offer = sagaOffer else { return nil }
        // Remembered at once, so a reload that runs while the answer is being saved cannot bring the card back.
        answeredSagaOffers.insert(offer.occasionID)
        sagaOffer = nil
        await useCases.answerSagaOffer.execute(occasionID: offer.occasionID)
        return accept ? offer.request : nil
    }
}
