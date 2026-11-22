import Foundation
import Testing

/// Checks the source catalog itself, so a half-written entry is caught before it reaches a screen (ADR-0027).
@Suite("Localizable.xcstrings")
struct CatalogTests {
    typealias Entry = [String: Any]

    static func entries() throws -> [String: Entry] {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/Localization/Resources/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        return json?["strings"] as? [String: Entry] ?? [:]
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

    @Test("Given level words in any case or accent, when folded as the test folds them, then each is caught")
    func levelWordsAreCaught() {
        for word in ["ΕΠΙΠΕΔΟ 3", "επιπεδο", "Επιπέδου", "LEVELS", "next Level"] {
            #expect(Self.speaksOfALevel(word), "\(word)")
        }
        #expect(!Self.speaksOfALevel("Οι δεξιότητές σου"))
    }

    @Test("Given the catalog, then every key has Greek and English text, and both plural forms where it is a plural")
    func everyEntryIsComplete() throws {
        let entries = try Self.entries()
        #expect(entries.count > 100)
        for (key, entry) in entries {
            #expect(Self.value(entry, "el")?.isEmpty == false, "Greek missing: \(key)")
            #expect(Self.value(entry, "en")?.isEmpty == false, "English missing: \(key)")
        }
    }

    @Test("Given the catalog, then every Greek text has the same placeholders as its key")
    func placeholdersMatch() throws {
        for (key, entry) in try Self.entries() {
            let greek = try #require(Self.value(entry, "el"))
            #expect(Self.placeholders(greek).sorted() == Self.placeholders(key).sorted(), "\(key)")
        }
    }
}
