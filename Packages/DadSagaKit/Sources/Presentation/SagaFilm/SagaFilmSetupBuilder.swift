import Application
import Domain
import Foundation
import Localization

/// What the sheet's choices show now, besides the film they are about.
struct SagaFilmChoices: Equatable, Sendable {
    var format: SagaFilmFormat
    var showsDates: Bool
    var music: Soundtrack
    var isListening: Bool
    var notice: String?
}

/// Builds the choices the sheet shows (ADR-0037 §4, ADR-0041 §5, ADR-0046 §2).
struct SagaFilmSetupBuilder {
    let locale: Locale
    let calendar: Calendar

    private var strings: Strings { Strings(locale: locale) }

    /// Also on the made film.
    var keepingNote: String {
        strings.text("Made on this iPhone from your photos and notes. It isn't kept: share it or save it to Photos.")
    }

    func setup(for film: SagaFilm, choices: SagaFilmChoices) -> SagaFilmSetup {
        let texts = SagaFilmTexts(locale: locale, calendar: calendar)
        let children = film.profile.children
        let hasSomething = film.hasSomethingToShow
        return SagaFilmSetup(
            childLabel: strings.text("Child"),
            periodLabel: strings.text("Period"),
            formatLabel: strings.text("Format"),
            note: keepingNote,
            children: children.count > 1 ? children.map { SagaFilmChildChoice(id: $0.id, name: $0.name) } : [],
            selectedChildID: film.child.id,
            periods: film.choosablePeriods.map { period in
                SagaFilmPeriodChoice(id: period.choiceID, title: texts.periodTitle(period, catalog: film.catalog))
            },
            selectedPeriodID: film.period.choiceID,
            formats: [
                SagaFilmFormatChoice(id: .vertical, title: strings.text("Vertical"), symbol: "rectangle.portrait"),
                SagaFilmFormatChoice(id: .wide, title: strings.text("Wide"), symbol: "rectangle")
            ],
            selectedFormat: choices.format,
            music: music(of: film, choices: choices),
            datesLabel: strings.text("Dates in the film"),
            datesNote: strings.text(
                "Dates also tell how old your child is. Turn them off for a film you'll share beyond the family."
            ),
            showsDates: choices.showsDates,
            notice: choices.notice,
            makeTitle: hasSomething ? strings.text(choices.notice == nil ? "Make the film" : "Make it again") : nil,
            emptyMessage: hasSomething
                ? nil
                : strings.text("Photos and moments you capture will show up here as a film.")
        )
    }

    private func music(of film: SagaFilm, choices: SagaFilmChoices) -> SagaFilmMusicSetup {
        SagaFilmMusicSetup(
            label: strings.text("Music"),
            choices: film.soundtracks.map {
                SagaFilmMusicChoice(id: $0.id, title: $0.title.resolved(for: locale), mood: $0.mood.resolved(for: locale))
            },
            selectedID: choices.music.id,
            isPlaying: choices.isListening,
            actionTitle: strings.text(choices.isListening ? "Stop the music" : "Listen to the music")
        )
    }
}

extension SagaFilm {
    /// The periods on offer, and the film's own if it is not one of them (one with nothing in it), so the choice
    /// shown is always in the list.
    var choosablePeriods: [SagaPeriod] {
        guard !availablePeriods.contains(period) else { return availablePeriods }
        return availablePeriods.filter { $0 != .everything } + [period] + availablePeriods.filter { $0 == .everything }
    }

    /// A film needs a scene of its own or something for its credits: an opening and credits alone say nothing.
    var hasSomethingToShow: Bool {
        storyboard.scenes.contains { scene in
            switch scene.kind {
            case .entry, .photo: true
            case .credits(let credits): credits.questsDone > 0 || credits.bossesBeaten > 0
            case .opening, .chapter: false
            }
        }
    }
}

extension SagaPeriod {
    /// Stable for a period, so a choice survives a reload: "year-2", "world-w2-plains", "everything".
    var choiceID: String {
        switch self {
        case .year(let number): "year-\(number)"
        case .world(let id): "world-\(id)"
        case .everything: "everything"
        }
    }
}
