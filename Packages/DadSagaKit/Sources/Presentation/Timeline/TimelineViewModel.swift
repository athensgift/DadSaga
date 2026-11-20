import Application
import Domain
import Foundation
import Localization
import Observation

/// Presenter for the timeline: everything the family has done, by month, for everyone or one child.
@MainActor
@Observable
public final class TimelineViewModel {
    public private(set) var state: TimelineViewState = .loading
    /// The child shown, or `nil` for everyone.
    public private(set) var selectedFilter: UUID?
    /// "Delete this?" while the dad is deciding.
    public private(set) var deletion: DeletionPrompt?
    public private(set) var errorMessage: String?
    /// The note and photo being edited, while the sheet is open.
    public private(set) var journalEditor: JournalEditor?
    public private(set) var isSaving = false

    private let getProfile: any GetProfileUseCase
    private let getTimeline: any GetTimelineUseCase
    private let getPhoto: any GetPhotoUseCase
    private let deleteEvent: any DeleteEventUseCase
    private let updateJournal: any UpdateJournalUseCase
    private let locale: Locale
    private let calendar: Calendar
    private var entries: [TimelineEntry] = []
    private var children: [Child] = []

    public init(
        getProfile: any GetProfileUseCase,
        getTimeline: any GetTimelineUseCase,
        getPhoto: any GetPhotoUseCase,
        deleteEvent: any DeleteEventUseCase,
        updateJournal: any UpdateJournalUseCase,
        locale: Locale = .current,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.getProfile = getProfile
        self.getTimeline = getTimeline
        self.getPhoto = getPhoto
        self.deleteEvent = deleteEvent
        self.updateJournal = updateJournal
        self.locale = locale
        self.calendar = calendar
    }

    /// Loads again every time, so it shows what was just done on the other tab.
    public func onAppear() async {
        do {
            children = try await getProfile.execute()?.children ?? []
            entries = try await getTimeline.execute()
            if let selectedFilter, !children.contains(where: { $0.id == selectedFilter }) {
                self.selectedFilter = nil
            }
            state = .loaded(makeContent())
        } catch {
            state = .failed(message: strings.text("The timeline failed to load."))
        }
    }

    public func select(filter: UUID?) {
        selectedFilter = filter
        state = .loaded(makeContent())
    }

    public func photoData(id: String, maxPixelSize: Int) async -> Data? {
        await getPhoto.execute(id: id, maxPixelSize: maxPixelSize)
    }

    /// Asks before deleting an entry. A moment with a photo or a note says plainly that those go too.
    public func requestDeletion(id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        errorMessage = nil
        let message: String
        switch entry.kind {
        case .first where entry.photoID != nil || entry.note != nil:
            message = strings.text(
                """
                Your photo and note will be deleted with it, for good. Its \(entry.xp) XP will be removed too.
                """
            )
        case .boss:
            message = strings.text("The badge and its \(entry.xp) XP will be removed.")
        default:
            message = strings.text("Its \(entry.xp) XP will be removed.")
        }
        deletion = DeletionPrompt(
            id: id,
            title: strings.text("Delete from the timeline?"),
            message: message,
            confirmTitle: strings.text("Delete"),
            cancelTitle: strings.text("Cancel")
        )
    }

    public func dismissError() {
        errorMessage = nil
    }

    public func cancelDeletion() {
        deletion = nil
    }

    /// Takes the id rather than reading `deletion`: the dialog clears its binding before the button's action runs.
    public func confirmDeletion(id: UUID) async {
        deletion = nil
        do {
            try await deleteEvent.execute(eventID: id)
            await onAppear()
        } catch {
            errorMessage = strings.text("Couldn't delete. Please try again.")
        }
    }

    /// Opens the note and photo of an entry, to add, change or remove them.
    public func editJournal(id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        errorMessage = nil
        journalEditor = JournalEditor(
            id: id,
            title: title(of: entry),
            note: entry.note ?? "",
            photoID: entry.photoID,
            labels: JournalLabels(locale: locale),
            saveTitle: strings.text("Save")
        )
    }

    public func closeJournal() {
        journalEditor = nil
    }

    public func saveJournal(note: String, photo: MomentPhotoEdit) async {
        guard let editor = journalEditor, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        let change: PhotoChange = switch photo {
        case .keep: .keep
        case .remove: .remove
        case .replace(let data): .replace(data)
        }
        do {
            try await updateJournal.execute(eventID: editor.id, note: note, photo: change)
            journalEditor = nil
            await onAppear()
        } catch {
            errorMessage = strings.text("Couldn't save. Please try again.")
        }
    }

    /// The film "Make a film" opens: the child the timeline is filtered to, or the first child's (ADR-0037 §6).
    public var filmRequest: SagaFilmRequest {
        SagaFilmRequest(childID: selectedFilter)
    }

    /// The labels of the row's actions.
    public var editTitle: String {
        strings.text("Note and photo")
    }

    /// The label of the row's delete action.
    public var deleteTitle: String {
        strings.text("Delete")
    }

    // MARK: Building

    private func makeContent() -> TimelineContent {
        let hasSiblings = children.count > 1
        let shown = entries.filter { selectedFilter == nil || $0.childID == selectedFilter }
        return TimelineContent(
            title: strings.text("Timeline"),
            filters: hasSiblings
                ? [TimelineFilter(id: nil, title: strings.text("All"))]
                    + children.map { TimelineFilter(id: $0.id, title: $0.name) }
                : [],
            selectedFilter: selectedFilter,
            sections: sections(for: shown, showChild: hasSiblings && selectedFilter == nil),
            emptyTitle: strings.text("No memories yet"),
            emptyMessage: strings.text("Everything you do with your kids will gather here."),
            filmTitle: shown.isEmpty ? nil : strings.text("Make a film")
        )
    }

    /// Entries are newest first, so consecutive entries of the same month form one section.
    private func sections(for entries: [TimelineEntry], showChild: Bool) -> [TimelineSection] {
        var sections: [TimelineSection] = []
        for entry in entries {
            let month = calendar.dateComponents([.year, .month], from: entry.date)
            let key = String(format: "%04d-%02d", month.year ?? 0, month.month ?? 0)
            let item = item(for: entry, showChild: showChild)
            if let last = sections.last, last.id == key {
                sections[sections.count - 1] = TimelineSection(id: key, title: last.title, items: last.items + [item])
            } else {
                sections.append(TimelineSection(id: key, title: monthTitle(entry.date), items: [item]))
            }
        }
        return sections
    }

    private func item(for entry: TimelineEntry, showChild: Bool) -> TimelineItem {
        let child = showChild ? children.first { $0.id == entry.childID }?.name : nil
        let day = entry.date.formatted(
            Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).day().month(.abbreviated)
        )
        let kind: TimelineItem.Kind
        let title: String
        let symbol: String
        var detail = entry.note
        switch entry.kind {
        case .quest(let quest):
            (kind, title, symbol) = (.quest, quest.title.resolved(for: locale), quest.skill.symbol)
        case .boss(let boss):
            (kind, title, symbol) = (.boss, boss.title.resolved(for: locale), "flame.fill")
            detail = [boss.badge.resolved(for: locale), entry.note].compactMap(\.self).joined(separator: " · ")
        case .first(let first):
            (kind, title, symbol) = (.moment, "\(first.emoji) \(first.title.resolved(for: locale))", "star.fill")
        }
        return TimelineItem(
            id: entry.id,
            kind: kind,
            title: title,
            subtitle: [child, day, detail].compactMap(\.self).joined(separator: " · "),
            badge: "+\(entry.xp) XP",
            symbol: symbol,
            photoID: entry.photoID
        )
    }

    private func title(of entry: TimelineEntry) -> String {
        switch entry.kind {
        case .quest(let quest): quest.title.resolved(for: locale)
        case .boss(let boss): boss.title.resolved(for: locale)
        case .first(let first): "\(first.emoji) \(first.title.resolved(for: locale))"
        }
    }

    /// The month on its own, e.g. "Νοέμβριος 2026" (not the "Νοεμβρίου" form used inside a date).
    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "LLLL y"
        let title = formatter.string(from: date)
        return title.prefix(1).uppercased(with: locale) + title.dropFirst()
    }

    private var strings: Strings { Strings(locale: locale) }
}
