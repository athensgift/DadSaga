import Application
import Domain
import Foundation

/// The calm card for a new title, e.g. "You became “Steady hands”. You got: Changing bag." (ADR-0055 §6). No
/// confetti, no sound, no haptic and nothing about the next title. It stays until the dad closes it.
public struct TitleCard: Equatable, Sendable {
    public let title: String
    /// What the titles since the last card brought the hero; `nil` when nothing is new on him.
    public let message: String?
    public let close: String
    /// The title the card is for, remembered when it is closed.
    let titleID: String
}

extension HomeViewModel {
    /// The card for the title home's query found, unless the dad has just closed it.
    func makeTitleCard(_ overview: HomeOverview) -> TitleCard? {
        guard let news = overview.standing.news, !closedTitleCards.contains(news.title.id) else { return nil }
        let gear = news.gear.map { $0.title.resolved(for: locale) }
        return TitleCard(
            title: strings.text("You became “\(news.title.name.resolved(for: locale))”."),
            message: gear.isEmpty
                ? nil
                : strings.text("You got: \(gear.formatted(.list(type: .and).locale(locale)))."),
            close: strings.text("Nice"),
            titleID: news.title.id
        )
    }

    /// One tap closes it for good, at once and through a reload; a higher title brings a new one.
    public func closeTitleCard() async {
        guard let card = titleCard else { return }
        closedTitleCards.insert(card.titleID)
        titleCard = nil
        // A film offer or the reminder waited behind it.
        if let overview { sagaOffer = makeSagaOffer(overview) }
        try? await useCases.markTitleSeen.execute(titleID: card.titleID)
        if sagaOffer == nil, let overview {
            reminderOffer = await makeReminderOffer(children: overview.profile.children, progress: overview.progress)
        }
    }
}
