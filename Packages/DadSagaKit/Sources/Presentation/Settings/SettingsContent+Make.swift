import Domain
import Foundation
import Localization

/// Everything Settings says, in the dad's language, with the rows the bundle's keys allow (ADR-0030).
extension SettingsContent {
    static func make(appInfo: AppInfo, locale: Locale) -> SettingsContent {
        let strings = Strings(locale: locale)
        return SettingsContent(
            title: strings.text("Settings"),
            preferencesSection: strings.text("Preferences"),
            languageTitle: strings.text("Language"),
            languageValue: languageName(locale),
            languageFooter: strings.text("iOS restarts DadSaga when you change the language."),
            appearanceTitle: strings.text("Appearance"),
            appearanceOptions: [
                AppearanceOption(id: .system, title: strings.text("Automatic")),
                AppearanceOption(id: .light, title: strings.text("Light")),
                AppearanceOption(id: .dark, title: strings.text("Dark"))
            ],
            hapticsTitle: strings.text("Haptics"),
            reminderTitle: strings.text("Weekly reminder"),
            heroSection: strings.text("Hero & family"),
            heroTitle: strings.text("Your hero"),
            wardrobeTitle: strings.text("Wardrobe"),
            familyTitle: strings.text("My family"),
            support: supportSection(appInfo: appInfo, strings: strings),
            about: AboutSection(
                title: strings.text("About"),
                versionTitle: strings.text("Version"),
                versionValue: "\(appInfo.version) (\(appInfo.build))",
                privacyStatement: strings.text(
                    """
                    DadSaga has no account and no tracking. Your family, quests, moments and photos stay on this \
                    iPhone, and in its backups if you make them.
                    """
                ),
                privacyPolicy: appInfo.privacyPolicyURL.map { LinkRow(title: strings.text("Privacy policy"), url: $0) }
            ),
            startOver: StartOverLabels(
                row: strings.text("Start over"),
                footer: strings.text("Deletes everything on this iPhone and opens the first screen again."),
                dialogTitle: strings.text("Start over?"),
                dialogMessage: strings.text(
                    """
                    Everything will be deleted from this iPhone: your family and hero, every quest, boss and moment \
                    with their notes and photos, your wardrobe and the weekly reminder. This can't be undone.
                    """
                ),
                confirm: strings.text("Delete everything"),
                cancel: strings.text("Cancel")
            )
        )
    }

    /// The language UI and content use, named in itself by Foundation.
    private static func languageName(_ locale: Locale) -> String {
        let code = LocalizedText.languageCode(for: locale)
        let language = Locale(identifier: code)
        return language.localizedString(forLanguageCode: code)?.capitalized(with: language) ?? code
    }

    private static func supportSection(appInfo: AppInfo, strings: Strings) -> SupportSection? {
        let contact = contactRow(appInfo: appInfo, strings: strings)
        let appPage = appInfo.appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)") }
        let rate = appPage
            .flatMap { URL(string: $0.absoluteString + "?action=write-review") }
            .map { LinkRow(title: strings.text("Rate DadSaga"), url: $0) }
        let share = appPage.map {
            ShareRow(
                title: strings.text("Tell a friend"),
                url: $0,
                subject: "DadSaga",
                message: strings.text(
                    "DadSaga turns the first years of fatherhood into a game. You're the hero, your kid is your companion."
                )
            )
        }
        guard contact != nil || rate != nil || share != nil else { return nil }
        return SupportSection(title: strings.text("Support"), contact: contact, rate: rate, share: share)
    }

    private static func contactRow(appInfo: AppInfo, strings: Strings) -> ContactRow? {
        guard let address = appInfo.feedbackAddress else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: strings.text("DadSaga feedback")),
            URLQueryItem(
                name: "body",
                value: "\n\n—\nDadSaga \(appInfo.version) (\(appInfo.build)) · iOS \(appInfo.systemVersion)"
            )
        ]
        guard let url = components.url else { return nil }
        return ContactRow(title: strings.text("Contact us"), address: address, mailURL: url)
    }
}
