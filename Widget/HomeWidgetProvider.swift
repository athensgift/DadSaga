import Foundation
import WidgetKit
import WidgetPresentation

struct HomeWidgetEntry: TimelineEntry, Sendable {
    let date: Date
    let content: HomeWidgetContent
}

/// One entry per timeline, refreshed when the week changes, or when the app leaves the screen (ADR-0023).
struct HomeWidgetProvider: AppIntentTimelineProvider {
    private var presenter: HomeWidgetPresenter { HomeWidgetPresenter(locale: .current) }

    func placeholder(in context: Context) -> HomeWidgetEntry {
        HomeWidgetEntry(date: .now, content: presenter.placeholder)
    }

    /// The widget gallery shows made-up content, never the family's.
    func snapshot(for configuration: SelectChildIntent, in context: Context) async -> HomeWidgetEntry {
        if context.isPreview { return HomeWidgetEntry(date: .now, content: presenter.sample) }
        return await timeline(for: configuration, in: context).entries.first ?? placeholder(in: context)
    }

    func timeline(for configuration: SelectChildIntent, in context: Context) async -> Timeline<HomeWidgetEntry> {
        let now = Date.now
        // Only the medium size has room for a photo, so the small one never decodes it.
        let wantsPhoto = configuration.showsPhoto && context.family == .systemMedium
        do {
            let highlights = try await WidgetContainer.highlights(
                childID: configuration.child?.id,
                on: now,
                withPhoto: wantsPhoto
            )
            let entry = HomeWidgetEntry(
                date: now,
                content: presenter.content(for: highlights, showsPhoto: configuration.showsPhoto)
            )
            return Timeline(entries: [entry], policy: highlights.map { .after($0.validUntil) } ?? .never)
        } catch {
            let entry = HomeWidgetEntry(date: now, content: presenter.content(for: nil, showsPhoto: false))
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60 * 60)))
        }
    }
}
