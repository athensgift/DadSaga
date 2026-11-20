import Application
import Domain
import Foundation
import Localization

/// The saga film's own words, in the user's language (ADR-0027): the name of a period and the credits. Content titles
/// come from the JSON (ADR-0005), and names stay exactly as the dad typed them.
struct SagaFilmTexts {
    let strings: Strings
    var locale: Locale { strings.locale }

    init(locale: Locale) {
        strings = Strings(locale: locale)
    }

    /// "Year 2", the world's title, or "The whole saga".
    func periodTitle(_ period: SagaPeriod, catalog: ContentCatalog) -> String {
        switch period {
        case .year(let number):
            strings.text("Year \(number)")
        case .world(let id):
            catalog.worlds.first { $0.id == id }?.title.resolved(for: locale) ?? strings.text("The whole saga")
        case .everything:
            strings.text("The whole saga")
        }
    }

    func chapterHeading(_ number: Int) -> String {
        strings.text("Chapter \(number)")
    }

    /// Roles, and only what the dad did in the period: a count of zero is left out, and with it the whole line when
    /// there is nothing to count (ADR-0006).
    func credits(_ credits: SagaCredits, in film: SagaFilm) -> SagaFilmCredits {
        let hero = film.catalog.heroClasses.first { $0.id == film.profile.heroClassID }
        let done = [
            credits.questsDone > 0 ? strings.text("\(credits.questsDone) quests") : nil,
            credits.bossesBeaten > 0 ? strings.text("\(credits.bossesBeaten) bosses") : nil
        ].compactMap(\.self)
        let music = [
            film.soundtrack.title,
            film.soundtrack.artist,
            film.soundtrack.licence == .cc0 ? strings.text("Public domain (CC0)") : nil
        ].compactMap(\.self)
        return SagaFilmCredits(
            lines: [
                SagaFilmCreditLine(role: strings.text("Starring"), name: film.child.name),
                SagaFilmCreditLine(
                    role: strings.text("The hero"),
                    name: hero?.title.resolved(for: locale) ?? strings.text("Hero")
                ),
                done.isEmpty ? nil : SagaFilmCreditLine(role: strings.text("Together"), name: done.joined(separator: " · ")),
                SagaFilmCreditLine(role: strings.text("Music"), name: music.joined(separator: " · "))
            ].compactMap(\.self),
            signature: strings.text("Made with DadSaga")
        )
    }
}
