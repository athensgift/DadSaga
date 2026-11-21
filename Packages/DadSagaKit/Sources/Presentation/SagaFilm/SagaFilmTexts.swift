import Application
import Domain
import Foundation
import Localization

/// The saga film's own words, in the user's language (ADR-0027): the name of a period, its dates and the credits.
/// Content titles come from the JSON (ADR-0005), and names stay exactly as the dad typed them. Dates are written by
/// Foundation in the film's locale, with the sheet's calendar and time zone (ADR-0041 §3).
struct SagaFilmTexts {
    let strings: Strings
    let calendar: Calendar
    var locale: Locale { strings.locale }

    /// `calendar` writes the dates; only the period's name and the credits need none.
    init(locale: Locale, calendar: Calendar = .autoupdatingCurrent) {
        strings = Strings(locale: locale)
        self.calendar = calendar
    }

    /// The day something happened: "March 12, 2026", "12 Μαρτίου 2026".
    func day(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(
            date: .long, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone
        ))
    }

    /// The months a film covers: "March 2025 – March 2026", "March – November 2026", or one month once.
    func span(_ span: DateInterval) -> String {
        Date.IntervalFormatStyle(date: nil, time: nil, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .month(.wide)
            .year()
            .format(span.start..<span.end)
    }

    /// "Year 2", the world's title, or "The whole saga".
    func periodTitle(_ period: SagaPeriod, catalog: ContentCatalog) -> String {
        switch period {
        case .year(let number):
            strings.text("Year \(number)")
        case .world(let id):
            catalog.world(id: id)?.title.resolved(for: locale) ?? strings.text("The whole saga")
        case .everything:
            strings.text("The whole saga")
        }
    }

    func chapterHeading(_ number: Int) -> String {
        strings.text("Chapter \(number)")
    }

    /// Roles, and only what the dad did in the period: a count of zero is left out, and with it the whole line when
    /// there is nothing to count (ADR-0006). The music is the track chosen, its title in the film's language (ADR-0046 §5).
    func credits(_ credits: SagaCredits, in film: SagaFilm, music: Soundtrack) -> SagaFilmCredits {
        let hero = film.catalog.hero(for: film.profile)
        let done = [
            credits.questsDone > 0 ? strings.text("\(credits.questsDone) quests") : nil,
            credits.bossesBeaten > 0 ? strings.text("\(credits.bossesBeaten) bosses") : nil
        ].compactMap(\.self)
        let musicCredit = [
            music.title.resolved(for: locale),
            music.artist,
            music.licence == .cc0 ? strings.text("Public domain (CC0)") : nil
        ].compactMap(\.self)
        return SagaFilmCredits(
            lines: [
                SagaFilmCreditLine(role: strings.text("Starring"), name: film.child.name),
                SagaFilmCreditLine(
                    role: strings.text("The hero"),
                    name: hero?.title.resolved(for: locale) ?? strings.text("Hero")
                ),
                done.isEmpty ? nil : SagaFilmCreditLine(role: strings.text("Together"), name: done.joined(separator: " · ")),
                SagaFilmCreditLine(role: strings.text("Music"), name: musicCredit.joined(separator: " · "))
            ].compactMap(\.self),
            signature: strings.text("Made with DadSaga")
        )
    }
}
