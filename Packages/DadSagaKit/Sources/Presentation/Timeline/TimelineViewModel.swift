import Application
import Domain
import Foundation
import Observation

/// Presenter for the timeline: everything the family has done, by month, for everyone or one child.
@MainActor
@Observable
public final class TimelineViewModel {
    public private(set) var state: TimelineViewState = .loading
    /// The child shown, or `nil` for everyone.
    public private(set) var selectedFilter: UUID?

    private let getProfile: any GetProfileUseCase
    private let getTimeline: any GetTimelineUseCase
    private let getPhoto: any GetPhotoUseCase
    private let locale: Locale
    private let calendar: Calendar
    private var entries: [TimelineEntry] = []
    private var children: [Child] = []

    public init(
        getProfile: any GetProfileUseCase,
        getTimeline: any GetTimelineUseCase,
        getPhoto: any GetPhotoUseCase,
        locale: Locale = .current,
        calendar: Calendar = .current
    ) {
        self.getProfile = getProfile
        self.getTimeline = getTimeline
        self.getPhoto = getPhoto
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
            state = .failed(message: text(el: "Το χρονολόγιο δεν φόρτωσε.", en: "The timeline failed to load."))
        }
    }

    public func select(filter: UUID?) {
        selectedFilter = filter
        state = .loaded(makeContent())
    }

    public func photoData(id: String) async -> Data? {
        await getPhoto.execute(id: id)
    }

    // MARK: Building

    private func makeContent() -> TimelineContent {
        let hasSiblings = children.count > 1
        let shown = entries.filter { selectedFilter == nil || $0.childID == selectedFilter }
        return TimelineContent(
            title: text(el: "Χρονολόγιο", en: "Timeline"),
            filters: hasSiblings
                ? [TimelineFilter(id: nil, title: text(el: "Όλοι", en: "All"))]
                    + children.map { TimelineFilter(id: $0.id, title: $0.name) }
                : [],
            selectedFilter: selectedFilter,
            sections: sections(for: shown, showChild: hasSiblings && selectedFilter == nil),
            emptyTitle: text(el: "Καμία ανάμνηση ακόμα", en: "No memories yet"),
            emptyMessage: text(
                el: "Ό,τι κάνεις με τα παιδιά σου θα μαζεύεται εδώ.",
                en: "Everything you do with your kids will gather here."
            )
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
            detail = boss.badge.resolved(for: locale)
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

    private func text(el: String, en: String) -> String {
        LocalizedText(el: el, en: en).resolved(for: locale)
    }
}
