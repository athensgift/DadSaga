import Application
import Domain
import Foundation
import Localization

/// Turns this week's highlights into what the widget shows (ADR-0023).
public struct HomeWidgetPresenter: Sendable {
    /// Longest side of the photo the widget asks for: sharp on half a medium widget, still tiny in memory.
    public static let photoMaxPixelSize = 720

    /// Calm on purpose (ADR-0006): nothing "left", "missed" or counted down.
    private let strings: Strings
    private var locale: Locale { strings.locale }

    public init(locale: Locale = .current) {
        strings = Strings(locale: locale)
    }

    /// `nil` highlights mean there is no family yet (or the data could not be read).
    public func content(for highlights: WeeklyHighlights?, showsPhoto: Bool) -> HomeWidgetContent {
        guard let highlights else { return .message(strings.text("Open DadSaga to start the adventure.")) }
        return .tiles(
            HomeWidgetContent.Tiles(
                childName: highlights.childCount > 1 ? highlights.child.name : nil,
                quest: questTile(highlights),
                moment: momentTile(highlights, showsPhoto: showsPhoto)
            )
        )
    }

    /// Shown while WidgetKit is still loading: the layout, no data and no I/O.
    public var placeholder: HomeWidgetContent {
        .tiles(
            HomeWidgetContent.Tiles(
                childName: nil,
                quest: .init(header: questHeader, title: " ", skill: " ", doneText: nil, link: Self.appURL),
                moment: .init(header: momentHeader, emoji: "⭐️", title: " ", date: " ", photo: nil,
                              link: Self.appURL)
            )
        )
    }

    /// The widget gallery's preview. Made-up content, never the family's data.
    public var sample: HomeWidgetContent {
        .tiles(
            HomeWidgetContent.Tiles(
                childName: nil,
                quest: .init(
                    header: questHeader,
                    title: strings.text("Cuddle time"),
                    skill: strings.skill(.care),
                    doneText: nil,
                    link: Self.appURL
                ),
                moment: .init(
                    header: momentHeader,
                    emoji: "👣",
                    title: strings.text("First steps"),
                    date: day(.now),
                    photo: nil,
                    link: Self.appURL
                )
            )
        )
    }

    /// Opens the app as it is; used where there is no family data to point at.
    private static let appURL = URL(string: "\(AppLink.scheme)://") ?? URL(filePath: "/")

    private func questTile(_ highlights: WeeklyHighlights) -> HomeWidgetContent.QuestTile {
        let childID = highlights.child.id
        switch highlights.quest {
        case .suggested(let quest, let isDone):
            return .init(
                header: questHeader,
                title: quest.title.resolved(for: locale),
                skill: strings.skill(quest.skill),
                doneText: isDone ? strings.text("✓ Done this week") : nil,
                link: AppLink.quest(id: quest.id, childID: childID).url
            )
        case .comingSoon:
            return .init(
                header: questHeader,
                title: strings.text("Adventures for your child's age are coming soon."),
                skill: nil,
                doneText: nil,
                link: AppLink.child(childID).url
            )
        }
    }

    private func momentTile(
        _ highlights: WeeklyHighlights,
        showsPhoto: Bool
    ) -> HomeWidgetContent.MomentTile {
        guard let moment = highlights.latestMoment else {
            return .init(
                header: momentHeader,
                emoji: "⭐️",
                title: strings.text("Legendary moments you capture show up here."),
                date: nil,
                photo: nil,
                link: AppLink.child(highlights.child.id).url
            )
        }
        return .init(
            header: momentHeader,
            emoji: moment.first.emoji,
            title: moment.first.title.resolved(for: locale),
            date: day(moment.date),
            photo: showsPhoto ? highlights.momentPhoto : nil,
            link: AppLink.moment(eventID: moment.eventID, childID: highlights.child.id).url
        )
    }

    private var questHeader: String { strings.text("Quest of the week") }
    private var momentHeader: String { strings.text("Legendary moment") }

    private func day(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
    }
}
