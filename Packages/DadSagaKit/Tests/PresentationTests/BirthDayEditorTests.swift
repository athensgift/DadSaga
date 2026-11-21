import Application
import Domain
import Foundation
import Presentation
import Testing

/// A birth date is the day the dad picked, wherever the phone is (ADR-0048 §2): the pickers show the stored day and
/// save the day they show, without its time.
@MainActor
@Suite("Birth day in the editors")
struct BirthDayEditorTests {
    let update = SpyUpdateFamily()
    let save = SpySaveProfile()

    @Test("Given a child born on 15 March, when My family opens in Los Angeles and saves, then it shows and keeps 15 March")
    func familyEditorShowsTheStoredDay() async throws {
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let anna = Child(name: "Άννα", birthDay: .day(2025, 3, 15))
        let sut = FamilyViewModel(
            getProfile: StubGetProfile(profile: PlayerProfile(children: [anna], heroClassID: "h-cool")),
            updateFamily: update,
            locale: Locale(identifier: "el_GR"),
            now: HeroStub.today,
            timeZone: losAngeles,
            onSaved: {}
        )
        await sut.onAppear()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = losAngeles

        let shown = try #require(sut.family.children.first?.birthDate)
        #expect(calendar.dateComponents([.year, .month, .day], from: shown) == DateComponents(year: 2025, month: 3, day: 15))
        await sut.save()
        #expect(await update.saved?.first?.birthDay == .day(2025, 3, 15))
    }

    @Test("Given a birth date picked late in the evening in Auckland, when finishing, then the child's birth day is that day")
    func onboardingDropsTheTimeOfDay() async throws {
        let auckland = try #require(TimeZone(identifier: "Pacific/Auckland"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = auckland
        let evening = try #require(calendar.date(from: DateComponents(year: 2025, month: 3, day: 15, hour: 23, minute: 30)))
        let sut = OnboardingViewModel(
            loadCatalog: StubLoadCatalog(result: .success(HeroStub.catalog)),
            saveProfile: save,
            locale: Locale(identifier: "el_GR"),
            now: evening,
            timeZone: auckland,
            onFinished: {}
        )
        sut.family.children[0].name = "Άννα"
        sut.continueToHero()
        sut.selectHero(id: "h-cool")
        await sut.finish()

        #expect(await save.saved?.children.first?.birthDay == .day(2025, 3, 15))
    }
}
