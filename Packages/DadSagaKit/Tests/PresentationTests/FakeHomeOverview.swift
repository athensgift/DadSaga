import Application
import Domain
import Foundation

/// Home's overview from stubs: the family, the fake log and wardrobe, and an adventure per child. Built with the real
/// `HomeOverview`, so which world, quests, bosses and gear show follows the same rules as the app.
struct FakeHomeOverview: GetHomeOverviewUseCase {
    let profile: PlayerProfile?
    var catalog = HeroStub.catalog
    let progress: FakeProgress
    var outfit = FakeOutfit()
    var adventure: @Sendable (Child) -> Adventure = HeroStub.adventure
    /// The film offer home finds, until the dad answers it.
    var film = FakeFilmOffers()

    func execute(childID: UUID?, worldID: String?, on date: Date) async throws -> HomeOverview? {
        guard let profile, let child = profile.child(childID) else { return nil }
        let log = try await progress.overviewLog()
        return HomeOverview(
            profile: profile,
            child: child,
            catalog: catalog,
            adventure: adventure(child),
            progress: log.progress,
            moments: log.moments,
            kept: await progress.kept,
            outfit: await outfit.stored,
            worldID: worldID,
            sagaOffer: await film.pending,
            today: CalendarDay(date, in: .gmt)
        )
    }
}
