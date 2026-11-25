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
            bringBack: NoFamilyActs(),
            deleteForGood: NoFamilyActs(),
            locale: Locale(identifier: "el_GR"),
            now: { HeroStub.today },
            timeZone: losAngeles,
            onSaved: {}
        )
        await sut.onAppear()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = losAngeles

        let shown = try #require(sut.family.children.first?.pickerDate(in: losAngeles))
        #expect(calendar.dateComponents([.year, .month, .day], from: shown) == DateComponents(year: 2025, month: 3, day: 15))
        await sut.save()
        // Saved unchanged: the day stays as stored, so the edit sets none.
        #expect(await update.saved?.isEmpty == true)
    }

    @Test("Given My family opened in Athens, when the phone moves to London and a name changes, then every birth day is kept")
    func familyKeepsTheDaysWhenTheZoneChanges() async throws {
        let athens = try #require(TimeZone(identifier: "Europe/Athens"))
        let london = try #require(TimeZone(identifier: "Europe/London"))
        let children = [
            Child(name: "Άννα", birthDay: .day(2025, 3, 15)),
            Child(name: "Λευτέρης", birthDay: .day(2026, 5, 21))
        ]
        let profile = PlayerProfile(children: children, heroClassID: "h-cool")
        let openedInAthens = makeFamily(profile: profile, timeZone: athens)
        await openedInAthens.onAppear()
        let savedInLondon = makeFamily(profile: profile, timeZone: london)
        await savedInLondon.onAppear()

        savedInLondon.family = openedInAthens.family
        savedInLondon.family.children[0].name = "Αννούλα"
        await savedInLondon.save()

        let saved = try #require(await update.saved)
        #expect(saved.changed.map(\.child.id) == [children[0].id])
        #expect(saved.changed.first?.fields == [.name])
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
            now: { evening },
            timeZone: auckland,
            onFinished: {}
        )
        sut.family.children[0].name = "Άννα"
        sut.continueToHero()
        sut.selectHero(id: "h-cool")
        await sut.finish()

        #expect(await save.saved?.children.first?.birthDay == .day(2025, 3, 15))
    }

    @Test("Given a picker in Auckland, when the dad picks 15 March late in the evening, then the child is born on 15 March")
    func pickerKeepsOnlyTheDay() throws {
        let auckland = try #require(TimeZone(identifier: "Pacific/Auckland"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = auckland
        let evening = try #require(calendar.date(from: DateComponents(year: 2025, month: 3, day: 15, hour: 23, minute: 30)))
        var draft = ChildDraft(name: "Άννα", birthDay: .day(2024, 1, 1))

        draft.pickBirthDate(evening, in: auckland)

        #expect(draft.birthDay == .day(2025, 3, 15))
        #expect(calendar.isDate(draft.pickerDate(in: auckland), inSameDayAs: evening))
    }

    @Test("Given a child not born yet, when unticking it the day after the page opened, then the picker is at the new day")
    func bornTheNextDay() {
        var draft = ChildDraft(name: "Άννα", birthDay: .day(2025, 3, 15), isBorn: false)

        draft.setBorn(true, now: CalendarDay.day(2025, 3, 16).start(in: .gmt), in: .gmt)
        #expect(draft.birthDay == .day(2025, 3, 16))

        // A day he picked is his, however he moves the switch after.
        draft.pickBirthDate(CalendarDay.day(2025, 3, 14).start(in: .gmt), in: .gmt)
        draft.setBorn(false, now: CalendarDay.day(2025, 3, 16).start(in: .gmt), in: .gmt)
        draft.setBorn(true, now: CalendarDay.day(2025, 3, 17).start(in: .gmt), in: .gmt)
        #expect(draft.birthDay == .day(2025, 3, 14))
    }

    @Test("Given a stored birth day, when ticking not born and unticking it, then that day is back")
    func storedDayComesBack() async throws {
        let anna = Child(name: "Άννα", birthDay: .day(2025, 3, 15))
        let sut = makeFamily(profile: PlayerProfile(children: [anna], heroClassID: "h-cool"), timeZone: .gmt)
        await sut.onAppear()

        sut.family.children[0].setBorn(false, now: CalendarDay.day(2025, 6, 1).start(in: .gmt), in: .gmt)
        sut.family.children[0].setBorn(true, now: CalendarDay.day(2025, 6, 1).start(in: .gmt), in: .gmt)

        #expect(sut.family.children[0].birthDay == .day(2025, 3, 15))
        #expect(!sut.hasUnsavedChanges)
    }

    private func makeFamily(profile: PlayerProfile, timeZone: TimeZone) -> FamilyViewModel {
        FamilyViewModel(
            getProfile: StubGetProfile(profile: profile),
            updateFamily: update,
            bringBack: NoFamilyActs(),
            deleteForGood: NoFamilyActs(),
            locale: Locale(identifier: "el_GR"),
            now: { HeroStub.today },
            timeZone: timeZone,
            onSaved: {}
        )
    }
}
