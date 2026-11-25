import Foundation
import Testing

/// Checks the source catalog itself, so a half-written entry is caught before it reaches a screen (ADR-0027).
@Suite("Localizable.xcstrings")
struct CatalogTests {
    typealias Entry = [String: Any]

    /// The app's strings, and the two catalogs the system reads: the Info.plist's and the widget's.
    enum Catalog: String, CaseIterable {
        case app = "Packages/DadSagaKit/Sources/Localization/Resources/Localizable.xcstrings"
        case infoPlist = "App/Resources/InfoPlist.xcstrings"
        case widget = "Widget/Localizable.xcstrings"
    }

    /// The entries with words to translate. "DadSaga copy" is left out: Xcode's empty entry, the owner's to fill in.
    static func entries(_ catalog: Catalog = .app) throws -> [String: Entry] {
        var url = URL(filePath: #filePath)
        for _ in 1...5 { url.deleteLastPathComponent() }
        url.append(path: catalog.rawValue)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let entries = json?["strings"] as? [String: Entry] ?? [:]
        return entries.filter { key, entry in
            entry["shouldTranslate"] as? Bool != false && !(catalog == .infoPlist && key == "DadSaga copy")
        }
    }

    /// The "other" form for plurals, the plain value otherwise.
    static func value(_ entry: Entry, _ language: String) -> String? {
        let localization = (entry["localizations"] as? [String: Any])?[language] as? [String: Any]
        if let plural = (localization?["variations"] as? [String: Any])?["plural"] as? [String: Any] {
            let other = plural["other"] as? [String: Any]
            let one = (plural["one"] as? [String: Any])?["stringUnit"] as? [String: Any]
            guard (one?["value"] as? String)?.isEmpty == false else { return nil }
            return (other?["stringUnit"] as? [String: Any])?["value"] as? String
        }
        return (localization?["stringUnit"] as? [String: Any])?["value"] as? String
    }

    /// The state of every form of the text in `language`.
    static func states(_ entry: Entry, _ language: String) -> [String] {
        let localization = (entry["localizations"] as? [String: Any])?[language] as? [String: Any]
        let plural = (localization?["variations"] as? [String: Any])?["plural"] as? [String: Any]
        let forms = plural.map { $0.values.compactMap { $0 as? [String: Any] } } ?? [localization ?? [:]]
        return forms.map { ($0["stringUnit"] as? [String: Any])?["state"] as? String ?? "missing" }
    }

    /// Any case, accent and ending: "levels", "next level", «ΕΠΙΠΕΔΟ», «επιπέδου» or "Level 4/9".
    static func speaksOfALevel(_ text: String) -> Bool {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).contains(/level|επιπεδ/)
    }

    static func placeholders(_ text: String) -> [String] {
        let regex = /%(\d+\$)?(lld|@)/
        return text.matches(of: regex).map { String($0.output.2) }
    }

    @Test("Given the catalog, then no key or text speaks of XP, and a level only in «Επίπεδο %lld» (ADR-0055 §7, ADR-0059 §4)")
    func noXPOrLevels() throws {
        for (key, entry) in try Self.entries() {
            let texts = [key, Self.value(entry, "el") ?? "", Self.value(entry, "en") ?? ""]
            #expect(!texts.contains { $0.contains("XP") }, "XP in: \(key)")
            if key == "Level %lld" {
                #expect(texts == ["Level %lld", "Επίπεδο %lld", "Level %lld"], "the level's one key changed")
            } else {
                #expect(!texts.contains(where: Self.speaksOfALevel), "a level in: \(key)")
            }
        }
    }

    /// Any case and accent: "unlocks", "Locked", «ξεκλειδώνει», «κλειδωμένος»; never "clock" or "block".
    static func speaksOfALock(_ text: String) -> Bool {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).contains(/\b(un)?lock|κλειδ/)
    }

    @Test("Given the catalog, then no key or text speaks of unlocking or locks: every world is open (ADR-0061 §3)")
    func noLocks() throws {
        for (key, entry) in try Self.entries() {
            let texts = [key, Self.value(entry, "el") ?? "", Self.value(entry, "en") ?? ""]
            #expect(!texts.contains(where: Self.speaksOfALock), "a lock in: \(key)")
        }
    }

    @Test("Given level words in any case or accent, when folded as the test folds them, then each is caught")
    func levelWordsAreCaught() {
        for word in ["ΕΠΙΠΕΔΟ 3", "επιπεδο", "Επιπέδου", "LEVELS", "next Level"] {
            #expect(Self.speaksOfALevel(word), "\(word)")
        }
        #expect(!Self.speaksOfALevel("Οι δεξιότητές σου"))
    }

    @Test(
        "Given a catalog, then every key has Greek and English text, translated, and both plural forms where it is a plural",
        arguments: Catalog.allCases
    )
    func everyEntryIsComplete(catalog: Catalog) throws {
        let entries = try Self.entries(catalog)
        #expect(entries.count > (catalog == .app ? 100 : 1))
        for (key, entry) in entries {
            for language in ["el", "en"] {
                #expect(Self.value(entry, language)?.isEmpty == false, "\(language) missing: \(key)")
                #expect(Self.states(entry, language).allSatisfy { $0 == "translated" }, "\(language) not translated: \(key)")
            }
        }
    }

    @Test("Given the Info.plist's catalog, then the privacy policy opens in the app's language")
    func privacyPolicyURLs() throws {
        let entry = try #require(try Self.entries(.infoPlist)["DadSagaPrivacyPolicyURL"])
        #expect(Self.value(entry, "el") == "https://dadsaga.app/el/privacy/")
        #expect(Self.value(entry, "en") == "https://dadsaga.app/privacy/")
    }

    @Test("Given a catalog, then every Greek text has the same placeholders as its key", arguments: [Catalog.app, .widget])
    func placeholdersMatch(catalog: Catalog) throws {
        for (key, entry) in try Self.entries(catalog) {
            let greek = try #require(Self.value(entry, "el"))
            #expect(Self.placeholders(greek).sorted() == Self.placeholders(key).sorted(), "\(key)")
        }
    }
}
