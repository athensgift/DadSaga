import Application
import Domain
import Foundation
import Testing
@testable import Presentation

/// The film's opening for a child not born yet (ADR-0053 §2): the hero and the child's mark.
@Suite("Saga film before birth")
struct SagaFilmBeforeBirthTests {
    @Test("Given a child not born yet with a first, when the film is scripted, then the opening draws the mark")
    func openingDrawsTheMark() throws {
        let child = Child(name: "Μπέμπης", birthDay: nil)
        let profile = PlayerProfile(children: [child], heroClassID: "h-cool")
        let catalog = HarbourStub.catalog
        let event = ProgressEvent(kind: .first(id: "f-found-out"), childID: child.id, date: HarbourStub.today)
        let storyboard = try #require(SagaStoryboard.make(
            events: [event], child: child, period: .world(id: "w0"), catalog: catalog,
            now: HarbourStub.today.addingTimeInterval(86_400), timeZone: .gmt
        ))
        let film = SagaFilm(
            profile: profile, child: child, catalog: catalog, storyboard: storyboard,
            availablePeriods: [.world(id: "w0"), .everything], medalCount: 0, childFirsts: [], equippedGear: [], title: nil,
            soundtracks: [FilmStub.theme], soundtrack: FilmStub.theme, showsDates: false
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt

        let script = SagaFilmScriptBuilder(locale: Locale(identifier: "el_GR"), calendar: calendar).script(
            for: film, format: .vertical, reduceMotion: false, showsDates: false, music: FilmStub.theme
        )

        guard case .opening(let name, _, _, let family) = script.scenes.first?.card else {
            Issue.record("Expected an opening, got \(String(describing: script.scenes.first))")
            return
        }
        #expect(name == "Μπέμπης")
        #expect(family.child.stage == .onTheWay)
        #expect(family.child.spokenName == "Μπέμπης, έρχεται")
    }
}
