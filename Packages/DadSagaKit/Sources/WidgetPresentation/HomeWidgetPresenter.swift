import Application
import Domain
import Foundation

/// Turns this week's highlights into what the widget shows (ADR-0023).
public struct HomeWidgetPresenter: Sendable {
    /// Longest side of the photo the widget asks for: sharp on half a medium widget, still tiny in memory.
    public static let photoMaxPixelSize = 720

    private let locale: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
    }

    /// `nil` highlights mean there is no family yet (or the data could not be read).
    public func content(for highlights: WeeklyHighlights?, showsPhoto: Bool) -> HomeWidgetContent {
        let strings = WidgetStrings(locale: locale)
        guard let highlights else { return .message(strings.openApp) }
        return .tiles(
            HomeWidgetContent.Tiles(
                childName: highlights.childCount > 1 ? highlights.child.name : nil,
                quest: questTile(highlights, strings: strings),
                moment: momentTile(highlights, showsPhoto: showsPhoto, strings: strings)
            )
        )
    }

    /// Shown while WidgetKit is still loading: the layout, no data and no I/O.
    public var placeholder: HomeWidgetContent {
        let strings = WidgetStrings(locale: locale)
        return .tiles(
            HomeWidgetContent.Tiles(
                childName: nil,
                quest: .init(header: strings.questHeader, title: " ", reward: " ", doneText: nil, link: Self.appURL),
                moment: .init(header: strings.momentHeader, emoji: "⭐️", title: " ", date: " ", photo: nil,
                              link: Self.appURL)
            )
        )
    }

    /// The widget gallery's preview. Made-up content, never the family's data.
    public var sample: HomeWidgetContent {
        let strings = WidgetStrings(locale: locale)
        return .tiles(
            HomeWidgetContent.Tiles(
                childName: nil,
                quest: .init(
                    header: strings.questHeader,
                    title: strings.text(el: "Ώρα αγκαλιάς", en: "Cuddle time"),
                    reward: "+15 XP · " + Skill.care.title.resolved(for: locale),
                    doneText: nil,
                    link: Self.appURL
                ),
                moment: .init(
                    header: strings.momentHeader,
                    emoji: "👣",
                    title: strings.text(el: "Πρώτα βήματα", en: "First steps"),
                    date: strings.day(.now),
                    photo: nil,
                    link: Self.appURL
                )
            )
        )
    }

    /// Opens the app as it is; used where there is no family data to point at.
    private static let appURL = URL(string: "\(AppLink.scheme)://") ?? URL(filePath: "/")

    private func questTile(_ highlights: WeeklyHighlights, strings: WidgetStrings) -> HomeWidgetContent.QuestTile {
        let childID = highlights.child.id
        switch highlights.quest {
        case .suggested(let quest, let isDone):
            return .init(
                header: strings.questHeader,
                title: quest.title.resolved(for: locale),
                reward: strings.reward(for: quest),
                doneText: isDone ? strings.doneThisWeek : nil,
                link: AppLink.quest(id: quest.id, childID: childID).url
            )
        case .comingSoon:
            return .init(header: strings.questHeader, title: strings.comingSoon, reward: nil, doneText: nil,
                         link: AppLink.child(childID).url)
        }
    }

    private func momentTile(
        _ highlights: WeeklyHighlights,
        showsPhoto: Bool,
        strings: WidgetStrings
    ) -> HomeWidgetContent.MomentTile {
        guard let moment = highlights.latestMoment else {
            return .init(header: strings.momentHeader, emoji: "⭐️", title: strings.noMoment, date: nil, photo: nil,
                         link: AppLink.child(highlights.child.id).url)
        }
        return .init(
            header: strings.momentHeader,
            emoji: moment.first.emoji,
            title: moment.first.title.resolved(for: locale),
            date: strings.day(moment.date),
            photo: showsPhoto ? highlights.momentPhoto : nil,
            link: AppLink.moment(eventID: moment.eventID, childID: highlights.child.id).url
        )
    }
}
