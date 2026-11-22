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

    /// Every captured moment, a retired first's too; "complete" once every first that can be offered at this age is
    /// captured (ADR-0053 §3, §6).
    func section(for child: Child, age: ChildAge, catalog: ContentCatalog, progress: DadProgress) -> MomentsSection {
        let moments = progress.moments(for: child.id)
        let captured = progress.capturedFirstIDs(for: child.id)
        let viewer = PhotoViewerLabels(locale: locale)
        return MomentsSection(
            title: strings.text("Legendary moments"),
            progress: "\(moments.count)",
            addTitle: strings.text("Capture a moment"),
            cards: moments.map { card($0, viewer: viewer) },
            emptyText: age == .beforeBirth
                ? strings.text("The day you found out, the first picture… Capture them here.")
                : strings.text("First smile, first steps… Capture them here when they happen."),
            isComplete: UnlockRules.firsts(in: catalog, age: age).allSatisfy { captured.contains($0.id) },
            viewer: viewer
        )
    }

    /// Step 1 for a new moment: the firsts that can be offered at this age and aren't captured yet, and when. Each
    /// first has its own earliest day: a first before birth any day, every other first from the birth day.
    func capture(
        for child: Child,
        age: ChildAge,
        catalog: ContentCatalog,
        progress: DadProgress,
        now: Date
    ) -> MomentCapture {
        let captured = progress.capturedFirstIDs(for: child.id)
        let options = UnlockRules.firsts(in: catalog, age: age).filter { !captured.contains($0.id) }.map { first in
            MomentOption(
                id: first.id,
                emoji: first.emoji,
                title: first.title.resolved(for: locale),
                earliestDate: earliestDate(of: first, for: child, now: now)
            )
        }
        let choice = MomentChoice(
            options: options,
            dateLabel: dateLabel,
            earliestDate: options.map(\.earliestDate).min() ?? now,
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
            isNew: isNew,
            heading: isNew ? strings.text("Saved! Want to keep something more?") : nil,
            line: isNew ? strings.text("Photos or a few words, now or whenever you like.") : nil,
            date: moment.date,
            note: moment.note ?? "",
            photoIDs: moment.photoIDs,
            dateLabel: dateLabel,
            earliestDate: min(earliestDate(of: moment.first, for: child, now: now), moment.date),
            latestDate: now,
            notePlaceholder: strings.text("What happened? (optional)"),
            saveTitle: strings.text("Save"),
            notNowTitle: strings.text("Not now"),
            labels: MomentLabels(
                journal: JournalLabels(locale: locale),
                delete: strings.text("Delete moment"),
                deleteConfirmation: strings.text("The moment and its photos will be removed. Your title and what you got stay."),
                cancel: strings.text("Cancel")
            ),
            undoOffer: undoOffer
        )
    }

    private var dateLabel: String { strings.text("When did it happen?") }

    /// A first before birth can be dated any day up to today; every other first from the start of the birth day, or
    /// today while the child is not born.
    private func earliestDate(of first: FirstMoment, for child: Child, now: Date) -> Date {
        guard !first.isBeforeBirth else { return .distantPast }
        return min(child.birthDay?.start(in: timeZone) ?? now, now)
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

    private func card(_ moment: CapturedMoment, viewer: PhotoViewerLabels) -> MomentCardModel {
        let date = moment.date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
        return MomentCardModel(
            id: moment.eventID,
            title: "\(moment.first.emoji) \(moment.first.title.resolved(for: locale))",
            subtitle: [date, moment.note].compactMap(\.self).joined(separator: " · "),
            photoIDs: moment.photoIDs,
            photoCount: viewer.photoCount(moment.photoIDs.count)
        )
    }
}
