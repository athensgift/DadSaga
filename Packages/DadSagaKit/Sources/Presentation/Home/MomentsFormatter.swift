import Application
import Domain
import Foundation
import Localization

/// Builds the legendary-moment parts of home: the section, the capture sheet and the traits they give a child.
struct MomentsFormatter {
    let strings: HomeStrings
    let locale: Locale

    func section(for child: Child, catalog: ContentCatalog, progress: DadProgress) -> MomentsSection {
        let moments = progress.moments(for: child.id)
        return MomentsSection(
            title: strings.text("Legendary moments"),
            progress: "\(moments.count)",
            addTitle: strings.text("Capture a moment"),
            cards: moments.map(card),
            emptyText: strings.text("First smile, first steps… Capture them here when they happen."),
            isComplete: moments.count >= catalog.firsts.count
        )
    }

    func capture(for child: Child, catalog: ContentCatalog, progress: DadProgress, now: Date) -> MomentCapture {
        let captured = progress.capturedFirstIDs(for: child.id)
        return sheet(
            for: child,
            options: catalog.firsts.filter { !captured.contains($0.id) },
            editing: nil,
            now: now
        )
    }

    /// The same sheet, filled in with a moment that already exists.
    func edit(_ moment: CapturedMoment, for child: Child, now: Date) -> MomentCapture {
        sheet(
            for: child,
            options: [moment.first],
            editing: MomentEditing(momentID: moment.eventID, date: moment.date, note: moment.note ?? "", photoID: moment.photoID),
            now: now
        )
    }

    private func sheet(for child: Child, options: [FirstMoment], editing: MomentEditing?, now: Date) -> MomentCapture {
        MomentCapture(
            id: UUID(),
            title: child.name,
            options: options.map { first in
                MomentOption(
                    id: first.id,
                    emoji: first.emoji,
                    title: first.title.resolved(for: locale),
                    reward: "+\(first.xp) XP"
                )
            },
            dateLabel: strings.text("When did it happen?"),
            earliestDate: min(child.birthDate, editing?.date ?? now, now),
            latestDate: now,
            notePlaceholder: strings.text("What happened? (optional)"),
            saveTitle: strings.text("Save"),
            labels: MomentPhotoLabels(
                photo: PhotoLabels(locale: locale),
                delete: strings.text("Delete moment"),
                deleteConfirmation: strings.text("The moment, its photo and its XP will be removed."),
                cancel: strings.text("Cancel")
            ),
            editing: editing
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

    private func card(_ moment: CapturedMoment) -> MomentCardModel {
        let date = moment.date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
        return MomentCardModel(
            id: moment.eventID,
            title: "\(moment.first.emoji) \(moment.first.title.resolved(for: locale))",
            subtitle: [date, moment.note].compactMap(\.self).joined(separator: " · "),
            badge: "+\(moment.first.xp) XP",
            photoID: moment.photoID
        )
    }
}

/// What home was last built from.
struct HomeSnapshot {
    let child: Child
    let catalog: ContentCatalog
    let progress: DadProgress
    let adventure: Adventure
    /// Children in the family, for bosses that need a sibling.
    let childCount: Int
}
