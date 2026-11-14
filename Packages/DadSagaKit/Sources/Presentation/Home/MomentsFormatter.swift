import Domain
import Foundation

/// Builds the legendary-moment parts of home: the section, the capture sheet and the traits they give a child.
struct MomentsFormatter {
    let strings: HomeStrings
    let locale: Locale

    func section(for child: Child, catalog: ContentCatalog, progress: DadProgress) -> MomentsSection {
        let moments = progress.moments(for: child.id)
        return MomentsSection(
            title: strings.text(el: "Θρυλικές στιγμές", en: "Legendary moments"),
            progress: "\(moments.count) / \(catalog.firsts.count)",
            addTitle: strings.text(el: "Κατέγραψε στιγμή", en: "Capture a moment"),
            cards: moments.map(card),
            emptyText: strings.text(
                el: "Το πρώτο χαμόγελο, τα πρώτα βήματα… Κατέγραψέ τα εδώ όταν συμβούν.",
                en: "First smile, first steps… Capture them here when they happen."
            ),
            isComplete: moments.count >= catalog.firsts.count
        )
    }

    func capture(for child: Child, catalog: ContentCatalog, progress: DadProgress, now: Date) -> MomentCapture {
        let captured = progress.capturedFirstIDs(for: child.id)
        return MomentCapture(
            id: UUID(),
            title: child.name,
            options: catalog.firsts.filter { !captured.contains($0.id) }.map { first in
                MomentOption(
                    id: first.id,
                    emoji: first.emoji,
                    title: first.title.resolved(for: locale),
                    reward: "+\(first.xp) XP"
                )
            },
            dateLabel: strings.text(el: "Πότε έγινε;", en: "When did it happen?"),
            earliestDate: min(child.birthDate, now),
            latestDate: now,
            notePlaceholder: strings.text(el: "Τι έγινε; (προαιρετικό)", en: "What happened? (optional)"),
            saveTitle: strings.text(el: "Αποθήκευση", en: "Save")
        )
    }

    /// Visible changes earned by the child's captured firsts.
    func traits(for child: Child, catalog: ContentCatalog, progress: DadProgress) -> Set<CompanionTrait> {
        let captured = progress.capturedFirstIDs(for: child.id)
        return Set(
            catalog.firsts
                .filter { captured.contains($0.id) }
                .compactMap { $0.companionTrait.flatMap(CompanionTrait.init(content:)) }
        )
    }

    private func card(_ moment: CapturedMoment) -> CardModel {
        let date = moment.date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
        return CardModel(
            id: "moment-" + moment.first.id,
            title: "\(moment.first.emoji) \(moment.first.title.resolved(for: locale))",
            subtitle: [date, moment.note].compactMap(\.self).joined(separator: " · "),
            badge: "+\(moment.first.xp) XP",
            symbol: "star.fill",
            kind: .legendary
        )
    }
}

/// What home was last built from.
struct HomeSnapshot {
    let child: Child
    let catalog: ContentCatalog
    let progress: DadProgress
}
