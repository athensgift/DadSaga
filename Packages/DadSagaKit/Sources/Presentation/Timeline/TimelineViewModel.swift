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
    /// The entry open for editing, while its sheet is open.
    public private(set) var editor: TimelineEditor?
    public private(set) var isSaving = false

    private let getProfile: any GetProfileUseCase
    private let getTimeline: any GetTimelineUseCase
    private let getPhoto: any GetPhotoUseCase
    private let deleteEvent: any DeleteEventUseCase
    private let updateJournal: any UpdateJournalUseCase
    private let updateMoment: any UpdateMomentUseCase
    private let locale: Locale
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private var entries: [TimelineEntry] = []
    private var children: [Child] = []

    public init(
        getProfile: any GetProfileUseCase,
        getTimeline: any GetTimelineUseCase,
        getPhoto: any GetPhotoUseCase,
        deleteEvent: any DeleteEventUseCase,
        updateJournal: any UpdateJournalUseCase,
        updateMoment: any UpdateMomentUseCase,
        locale: Locale = .current,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.getProfile = getProfile
        self.getTimeline = getTimeline
        self.getPhoto = getPhoto
        self.deleteEvent = deleteEvent
        self.updateJournal = updateJournal
        self.updateMoment = updateMoment
        self.locale = locale
        self.calendar = calendar
        self.now = now
    }

    /// Loads again every time, so it shows what was just done on the other tab.
    public func onAppear() async {
        // A timeline that loaded once stays if it can't be read again: it is still the dad's, only not refreshed.
        if await !load(), !isLoaded { state = .failed(failure) }
    }

    /// Reads again after a change. A failure shows here: entries from before the change would open an editor that could
    /// save the old words and photos over the new ones.
    private func loadAfterChange() async {
        if await !load() { state = .failed(failure) }
    }

    /// Whether the timeline could be read.
    private func load() async -> Bool {
        do {
            let children = try await getProfile.execute()?.children ?? []
            entries = try await getTimeline.execute()
            self.children = children
        } catch {
            return false
        }
        if let selectedFilter, !children.contains(where: { $0.id == selectedFilter }) {
            self.selectedFilter = nil
        }
        state = .loaded(makeContent())
        return true
    }

    private var isLoaded: Bool {
        if case .loaded = state { true } else { false }
    }

    private var failure: LoadFailure {
        LoadFailure(message: strings.text("The timeline failed to load."), retryTitle: strings.text("Try again"))
    }

    public func select(filter: UUID?) {
        selectedFilter = filter
        state = .loaded(makeContent())
    }

    public func photoData(id: String, maxPixelSize: Int) async -> Data? {
        await getPhoto.execute(id: id, maxPixelSize: maxPixelSize)
    }

    /// Asks before deleting an entry. One with photos or a note says plainly that they go too, for good.
    public func requestDeletion(id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        errorMessage = nil
        let isBoss = if case .boss = entry.kind { true } else { false }
        // Only the entry, and a boss's badge, go: the title and gear stay (ADR-0055 §3, §7).
        let stays = isBoss
            ? strings.text("Its badge will be removed. Your title and what you got stay.")
            : strings.text("Your title and what you got stay.")
        let hasJournal = !entry.photoIDs.isEmpty || entry.note != nil
        let message = hasJournal
            ? strings.text("Your photos and note will be deleted with it, for good.") + " " + stays
            : stays
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
            await loadAfterChange()
        } catch {
            errorMessage = strings.text("Couldn't delete. Please try again.")
        }
    }

    /// Opens an entry to edit: a quest's or a boss's note and photos, or a first's own page, the same one home opens,
    /// with its date too (ADR-0042 §5).
    public func edit(id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        errorMessage = nil
        switch entry.kind {
        case .quest(let quest):
            editor = .journal(journalEditor(for: entry, title: quest.title.resolved(for: locale)))
        case .boss(let boss):
            editor = .journal(journalEditor(for: entry, title: boss.title.resolved(for: locale)))
        case .first(let first):
            guard let child = children.first(where: { $0.id == entry.childID }) else { return }
            let moment = CapturedMoment(
                eventID: entry.id,
                authorID: entry.authorID,
                first: first,
                date: entry.date,
                note: entry.note,
                photoIDs: entry.photoIDs
            )
            editor = .moment(momentsFormatter.details(moment, for: child, now: now(), isNew: false))
        }
    }

    public func closeEditor() {
        editor = nil
        // A failed save was shown in the sheet; it goes with it.
        errorMessage = nil
    }

    /// A link from outside is about to open home. The delete question closes; nothing is lost by it. The editor closes
    /// only if that loses nothing: not while it saves, and not while it holds changes the dad hasn't saved (ADR-0050).
    /// The root holds a link back meanwhile, so this is the last check, not the only one.
    public func linkWillOpen(editorHoldsChanges: Bool) {
        deletion = nil
        guard editor != nil, !isSaving, !editorHoldsChanges else { return }
        closeEditor()
    }

    /// Save in a quest's or a boss's editor.
    public func saveJournal(note: String, photos: PhotoDrafts) async {
        guard case .journal(let journal) = editor else { return }
        await perform {
            try await self.updateJournal.execute(eventID: journal.id, note: note, photos: photos.entryPhotos)
        }
    }

    /// Save in a first's page: its date, note and photos as the dad left them.
    public func saveMoment(date: Date, note: String, photos: PhotoDrafts) async {
        guard case .moment(let details) = editor else { return }
        await perform {
            try await self.updateMoment.execute(
                momentID: details.momentID, happenedOn: date, note: note, photos: photos.entryPhotos, now: self.now()
            )
        }
    }

    /// Delete, confirmed in a first's page: the moment goes with its photos. His title stays (ADR-0055 §3).
    public func deleteMoment() async {
        guard case .moment(let details) = editor else { return }
        await perform(orSay: strings.text("Couldn't delete. Please try again.")) {
            try await self.deleteEvent.execute(eventID: details.momentID)
        }
    }

    /// Runs a change to the open entry: closes its sheet and reloads, or shows the error in the sheet and keeps it open.
    private func perform(orSay failure: String? = nil, _ action: () async throws -> Void) async {
        guard !isSaving else { return }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await action()
            editor = nil
            await loadAfterChange()
        } catch {
            errorMessage = failure ?? strings.text("Couldn't save. Please try again.")
        }
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
            filmTitle: shown.isEmpty ? nil : strings.text("Make a film"),
            viewer: PhotoViewerLabels(locale: locale)
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
            symbol: symbol,
            photoIDs: entry.photoIDs,
            photoCount: PhotoViewerLabels(locale: locale).photoCount(entry.photoIDs.count)
        )
    }

    private func journalEditor(for entry: TimelineEntry, title: String) -> JournalEditor {
        JournalEditor(
            id: entry.id,
            title: title,
            note: entry.note ?? "",
            photoIDs: entry.photoIDs,
            labels: JournalLabels(locale: locale),
            saveTitle: strings.text("Save")
        )
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

    private var momentsFormatter: MomentsFormatter {
        MomentsFormatter(strings: HomeStrings(locale: locale), locale: locale, timeZone: calendar.timeZone)
    }
}

// MARK: A timeline that couldn't load

extension TimelineViewModel {
    /// "Try again", after the first load failed.
    public func retry() async {
        guard case .failed = state else { return }
        state = .loading
        await onAppear()
    }
}

// MARK: The rows' labels and the film

extension TimelineViewModel {
    /// The film "Make a film" opens: the child the timeline is filtered to, or the first child's (ADR-0037 §6).
    public var filmRequest: SagaFilmRequest {
        SagaFilmRequest(childID: selectedFilter)
    }

    /// The labels of the row's actions.
    public var editTitle: String {
        strings.text("Note and photos")
    }

    /// The label of the row's delete action.
    public var deleteTitle: String {
        strings.text("Delete")
    }
}
