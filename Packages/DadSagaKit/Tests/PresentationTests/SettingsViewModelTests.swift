import Application
import Domain
import Foundation
import Presentation
import Testing

@MainActor
@Suite("SettingsViewModel")
struct SettingsViewModelTests {
    let preferences = FakePreferences()
    let startOver = SpyStartOver()
    let root = SpyRoot()

    func makeSUT(
        appInfo: AppInfo = AppInfo(version: "0.1.0", build: "1", systemVersion: "26.1"),
        locale: String = "el_GR",
        current: PreferencesChoice = PreferencesChoice(),
        save: any SavePreferencesUseCase
    ) -> SettingsViewModel {
        let root = root
        return SettingsViewModel(
            useCases: SettingsViewModel.UseCases(savePreferences: save, startOver: startOver),
            preferences: current,
            appInfo: appInfo,
            actions: SettingsActions(
                onPreferencesChanged: { root.preferences.append($0) },
                onStartedOver: { root.startedOver += 1 }
            ),
            locale: Locale(identifier: locale)
        )
    }

    func makeSUT(
        appInfo: AppInfo = AppInfo(version: "0.1.0", build: "1", systemVersion: "26.1"),
        locale: String = "el_GR",
        current: PreferencesChoice = PreferencesChoice()
    ) -> SettingsViewModel {
        makeSUT(appInfo: appInfo, locale: locale, current: current, save: preferences as any SavePreferencesUseCase)
    }

    @Test("Given a Greek iPhone, when opening, then the language row says Ελληνικά and the titles are Greek")
    func greek() async throws {
        let content = makeSUT().content

        #expect(content.title == "Ρυθμίσεις")
        #expect(content.languageValue == "Ελληνικά")
        #expect(content.appearanceOptions.map(\.title) == ["Αυτόματα", "Ανοιχτή", "Σκούρα"])
        #expect(content.about.versionValue == "0.1.0 (1)")
    }

    @Test("Given an English iPhone, when opening, then the language row says English")
    func english() async throws {
        let content = makeSUT(locale: "en_US").content

        #expect(content.title == "Settings")
        #expect(content.languageValue == "English")
        #expect(content.appearanceOptions.map(\.title) == ["Automatic", "Light", "Dark"])
    }

    @Test("Given no address, App Store id or policy yet, when opening, then help and the policy row are hidden")
    func nothingConfigured() async throws {
        let content = makeSUT().content

        #expect(content.support == nil)
        #expect(content.about.privacyPolicy == nil)
        #expect(content.about.privacyStatement.hasPrefix("Το DadSaga δεν έχει λογαριασμό ούτε παρακολούθηση."))
    }

    @Test("Given a feedback address, when opening, then contact opens Mail with the subject and the versions")
    func contact() async throws {
        let info = AppInfo(version: "0.1.0", build: "1", systemVersion: "26.1", feedbackAddress: "hi@example.com")
        let contact = try #require(makeSUT(appInfo: info, locale: "en_US").content.support?.contact)

        let parts = try #require(URLComponents(url: contact.mailURL, resolvingAgainstBaseURL: false))
        #expect(parts.scheme == "mailto")
        #expect(parts.path == "hi@example.com")
        #expect(parts.queryItems?.first { $0.name == "subject" }?.value == "DadSaga feedback")
        #expect(parts.queryItems?.first { $0.name == "body" }?.value?.hasSuffix("DadSaga 0.1.0 (1) · iOS 26.1") == true)
    }

    @Test("Given an App Store id, when opening, then rate opens the review page and share sends the app's page")
    func rateAndShare() async throws {
        let info = AppInfo(version: "0.1.0", build: "1", systemVersion: "26.1", appStoreID: "123")
        let support = try #require(makeSUT(appInfo: info).content.support)

        #expect(support.contact == nil)
        #expect(support.rate?.url.absoluteString == "https://apps.apple.com/app/id123?action=write-review")
        #expect(support.share?.url.absoluteString == "https://apps.apple.com/app/id123")
        #expect(support.share?.title == "Πες το σε έναν φίλο")
        #expect(support.share?.subject == "DadSaga")
    }

    @Test("Given Mail did not open, when iOS reports it, then the address is offered to copy")
    func mailFallback() async throws {
        let info = AppInfo(version: "0.1.0", build: "1", systemVersion: "26.1", feedbackAddress: "hi@example.com")
        let sut = makeSUT(appInfo: info, locale: "en_US")

        sut.mailOpened(true)
        #expect(sut.mailFallback == nil)
        sut.mailOpened(false)
        #expect(sut.mailFallback?.address == "hi@example.com")
    }

    @Test("Given Automatic and haptics on, when choosing Dark and turning haptics off, then both are stored and the root follows")
    func changesPreferences() async throws {
        let sut = makeSUT()

        await sut.setAppearance(.dark)
        await sut.setHapticsEnabled(false)

        #expect(await preferences.stored == Preferences(appearance: .dark, hapticsEnabled: false))
        #expect(root.preferences.last == PreferencesChoice(appearance: .dark, isHapticsEnabled: false))
        #expect(sut.preferences == PreferencesChoice(appearance: .dark, isHapticsEnabled: false))
    }

    @Test("Given the start-over dialog, when it shows, then it says plainly that everything is deleted")
    func startOverCopy() async throws {
        let content = makeSUT().content

        #expect(content.startOver.dialogTitle == "Να ξεκινήσεις από την αρχή;")
        #expect(content.startOver.dialogMessage.hasSuffix("Δεν αναιρείται."))
        #expect(content.startOver.confirm == "Διαγραφή όλων")
    }

    @Test("Given an English iPhone, when Settings opens, then the dialog and the privacy statement are in English")
    func englishCopy() {
        let content = makeSUT(locale: "en_US").content

        #expect(content.startOver.dialogTitle == "Start over?")
        #expect(content.startOver.dialogMessage.hasSuffix("This can't be undone."))
        #expect(content.about.privacyStatement.hasPrefix("DadSaga has no account and no tracking."))
    }

    @Test("Given Dark with haptics off at the root, when Settings opens, then it shows them without reading storage")
    func opensWithRootPreferences() {
        let current = PreferencesChoice(appearance: .dark, isHapticsEnabled: false)

        #expect(makeSUT(current: current).preferences == current)
    }

    @Test("Given Automatic, when choosing Automatic again, then nothing is stored and the root is not told")
    func unchangedChoice() async {
        let sut = makeSUT()

        await sut.setAppearance(.system)

        #expect(root.preferences.isEmpty)
        #expect(await preferences.saveCount == 0)
    }

    @Test("Given a slow first save, when changing appearance then haptics, then the store ends with both changes")
    func savesInOrder() async {
        let slow = SlowFirstPreferences()
        let sut = makeSUT(save: slow)

        async let appearance: Void = sut.setAppearance(.dark)
        async let haptics: Void = sut.setHapticsEnabled(false)
        _ = await (appearance, haptics)

        #expect(await slow.stored == Preferences(appearance: .dark, hapticsEnabled: false))
        #expect(root.preferences.last == PreferencesChoice(appearance: .dark, isHapticsEnabled: false))
    }

    @Test("Given the dialog, when cancelling, then nothing is erased")
    func cancelStartOver() async throws {
        let sut = makeSUT()

        sut.askToStartOver()
        #expect(sut.isConfirmingStartOver)
        sut.isConfirmingStartOver = false

        #expect(await startOver.callCount == 0)
        #expect(root.startedOver == 0)
    }

    @Test("Given two quick confirmations, when starting over, then the saga is erased once and onboarding opens once")
    func startsOverOnce() async throws {
        let sut = makeSUT()

        async let first: Void = sut.startOver()
        async let second: Void = sut.startOver()
        _ = await (first, second)

        #expect(await startOver.callCount == 1)
        #expect(root.startedOver == 1)
    }

    @Test("Given erasing fails, when starting over, then an error shows and the dad stays on Settings")
    func startOverFailure() async throws {
        let sut = makeSUT()
        await startOver.failNext()

        await sut.startOver()

        #expect(sut.errorMessage == "Η διαγραφή δεν έγινε. Δεν άλλαξε τίποτα. Δοκίμασε ξανά.")
        #expect(root.startedOver == 0)
        #expect(!sut.isStartingOver)
    }
}

@MainActor
final class SpyRoot {
    var preferences: [PreferencesChoice] = []
    var startedOver = 0
}

actor FakePreferences: SavePreferencesUseCase {
    private(set) var stored = Preferences.default
    private(set) var saveCount = 0

    func execute(_ preferences: Preferences) async {
        saveCount += 1
        stored = preferences
    }
}

/// Takes a while to store the first change, like a slow disk.
actor SlowFirstPreferences: SavePreferencesUseCase {
    private(set) var stored = Preferences.default
    private var calls = 0

    func execute(_ preferences: Preferences) async {
        calls += 1
        if calls == 1 { try? await Task.sleep(for: .milliseconds(100)) }
        stored = preferences
    }
}

actor SpyStartOver: StartOverUseCase {
    private(set) var callCount = 0
    private var shouldFail = false

    func failNext() {
        shouldFail = true
    }

    func execute(on date: Date) async throws {
        callCount += 1
        // Gives a second tap the chance to arrive while the first is still erasing.
        await Task.yield()
        if shouldFail { throw StubError.boom }
    }
}
