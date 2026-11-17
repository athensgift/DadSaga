import Domain
import Foundation

/// Widget text in the user's language. Calm on purpose (ADR-0006): nothing "left", "missed" or counted down.
struct WidgetStrings {
    let locale: Locale

    var questHeader: String { text(el: "Αποστολή της εβδομάδας", en: "Quest of the week") }
    var doneThisWeek: String { text(el: "✓ Έγινε αυτή την εβδομάδα", en: "✓ Done this week") }
    /// Home's own line (ADR-0023), so the widget and the app say the same thing.
    var comingSoon: String {
        text(el: "Οι περιπέτειες για την ηλικία του παιδιού σου έρχονται σύντομα.",
             en: "Adventures for your child's age are coming soon.")
    }
    var momentHeader: String { text(el: "Θρυλική στιγμή", en: "Legendary moment") }
    var noMoment: String {
        text(el: "Οι θρυλικές στιγμές που καταγράφεις θα εμφανίζονται εδώ.",
             en: "Legendary moments you capture show up here.")
    }
    var openApp: String {
        text(el: "Άνοιξε το DadSaga για να ξεκινήσει η περιπέτεια.", en: "Open DadSaga to start the adventure.")
    }

    func reward(for quest: Quest) -> String {
        "+\(quest.xp) XP · \(quest.skill.title.resolved(for: locale))"
    }

    func day(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
    }

    func text(el: String, en: String) -> String {
        LocalizedText(el: el, en: en).resolved(for: locale)
    }
}
