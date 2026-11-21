import Application
import Domain
import Foundation
import Localization

/// Builds the legendary-moment parts of home: the section, the sheet's two steps and the traits they give a child.
struct MomentsFormatter {
    let strings: HomeStrings
    let locale: Locale
    /// For the start of the child's birth day: a moment can't be dated before it.
    let timeZone: TimeZone

    func section(for child: Child, catalog: ContentCatalog, progress: DadProgress) -> MomentsSection {
        let moments = progress.moments(for: child.id)
        let viewer = PhotoViewerLabels(locale: locale)
        return MomentsSection(
            title: strings.text("Legendary moments"),
            progress: "\(moments.count)",
            addTitle: strings.text("Capture a moment"),
            cards: moments.map { card($0, viewer: viewer) },
            emptyText: strings.text("First smile, first steps… Capture them here when they happen."),
            isComplete: moments.count >= catalog.firsts.count,
            viewer: viewer
        )
    }

    /// Step 1 for a new moment: the firsts not captured yet, and when.
    func capture(for child: Child, catalog: ContentCatalog, progress: DadProgress, now: Date) -> MomentCapture {
        let captured = progress.capturedFirstIDs(for: child.id)
        let choice = MomentChoice(
            options: catalog.firsts.filter { !captured.contains($0.id) }.map { first in
                MomentOption(id: first.id, emoji: first.emoji, title: first.title.resolved(for: locale), reward: reward(first))
            },
            dateLabel: dateLabel,
            earliestDate: min(child.birthDay.start(in: timeZone), now),
            latestDate: now,
            nextLine: strings.text("Next, if you like: photos or a few words."),
            saveTitle: strings.text("Save")
        )
        return MomentCapture(id: UUID(), title: child.name, step: .choose(choice))
    }

    /// Step 2 for a moment: just recorded (`isNew`, with its undo) or opened to edit.
    func details(
        _ moment: CapturedMoment,
        for child: Child,
        now: Date,
        isNew: Bool,
        undoOffer: UndoOffer? = nil
    ) -> MomentDetails {
        MomentDetails(
            momentID: moment.eventID,
            title: "\(moment.first.emoji) \(moment.first.title.resolved(for: locale))",
            reward: reward(moment.first),
            isNew: isNew,
            heading: isNew ? strings.text("Saved! Want to keep something more?") : nil,
            line: isNew ? strings.text("Photos or a few words, now or whenever you like.") : nil,
            date: moment.date,
            note: moment.note ?? "",
            photoIDs: moment.photoIDs,
            dateLabel: dateLabel,
            earliestDate: min(child.birthDay.start(in: timeZone), moment.date, now),
            latestDate: now,
            notePlaceholder: strings.text("What happened? (optional)"),
            saveTitle: strings.text("Save"),
            notNowTitle: strings.text("Not now"),
            labels: MomentLabels(
                journal: JournalLabels(locale: locale),
                delete: strings.text("Delete moment"),
                deleteConfirmation: strings.text("The moment, its photos and its XP will be removed."),
                cancel: strings.text("Cancel")
            ),
            undoOffer: undoOffer
        )
    }

    private var dateLabel: String { strings.text("When did it happen?") }

    private func reward(_ first: FirstMoment) -> String { "+\(first.xp) XP" }

    /// Visible changes earned by the child's captured firsts.
    func traits(for child: Child, catalog: ContentCatalog, progress: DadProgress) -> Set<CompanionTrait> {
        let captured = progress.capturedFirstIDs(for: child.id)
        return Set(
            catalog.firsts
                .filter { captured.contains($0.id) }
                .compactMap { $0.companionTrait.flatMap(CompanionTrait.init(content:)) }
        )
    }

    private func card(_ moment: CapturedMoment, viewer: PhotoViewerLabels) -> MomentCardModel {
        let date = moment.date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
        return MomentCardModel(
            id: moment.eventID,
            title: "\(moment.first.emoji) \(moment.first.title.resolved(for: locale))",
            subtitle: [date, moment.note].compactMap(\.self).joined(separator: " · "),
            badge: reward(moment.first),
            photoIDs: moment.photoIDs,
            photoCount: viewer.photoCount(moment.photoIDs.count)
        )
    }
}
