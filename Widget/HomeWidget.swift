import DesignSystem
import SwiftUI
import WidgetKit
import WidgetPresentation

/// The weekly quest, and in the medium size the latest legendary moment (ADR-0023).
struct HomeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "HomeWidget", intent: SelectChildIntent.self, provider: HomeWidgetProvider()) { entry in
            HomeWidgetView(content: entry.content)
        }
        .configurationDisplayName("DadSaga")
        .description("The quest of the week and your latest legendary moment.")
        .supportedFamilies([.systemSmall, .systemMedium])
        // A tap cannot open the app from CarPlay.
        .disfavoredLocations([.carPlay], for: [.systemSmall])
        // The moment's photo fills its half edge to edge; the quest side keeps its own margins.
        .contentMarginsDisabled()
    }
}

struct HomeWidgetView: View {
    let content: HomeWidgetContent
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch content {
            case .message(let text):
                MessageTile(text: text)
            case .tiles(let tiles) where family == .systemMedium:
                HStack(spacing: 0) {
                    QuestTile(quest: tiles.quest, childName: tiles.childName)
                    MomentTile(moment: tiles.moment)
                }
                .widgetURL(tiles.quest.link)
            case .tiles(let tiles):
                QuestTile(quest: tiles.quest, childName: tiles.childName)
                    .widgetURL(tiles.quest.link)
            }
        }
        .containerBackground(for: .widget) { DSColor.surface }
    }
}

private struct QuestTile: View {
    let quest: HomeWidgetContent.QuestTile
    let childName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: "figure.and.child.holdinghands")
                Text(quest.header)
                    .lineLimit(1)
            }
            .font(DSFont.caption)
            .foregroundStyle(DSColor.accent)
            .widgetAccentable()
            if let childName {
                Text(childName)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(quest.title)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
            if let skill = quest.skill {
                Text(skill)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.xp)
                    .lineLimit(1)
            }
            if let doneText = quest.doneText {
                Text(doneText)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.xp)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(DSSpacing.m)
        .accessibilityElement(children: .combine)
    }
}

private struct MomentTile: View {
    let moment: HomeWidgetContent.MomentTile

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = moment.photo, let image = Image(imageData: data) {
                // The photo fills the half it is given; as an overlay its own shape never widens that half.
                Color.clear
                    .overlay {
                        image
                            .resizable()
                            .widgetAccentedRenderingMode(.desaturated)
                            .scaledToFill()
                    }
                    .clipped()
                    .privacySensitive()
                LinearGradient(colors: [.clear, DSColor.heroInk.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                caption(color: DSColor.heroHighlight)
            } else {
                DSColor.legendary.opacity(0.15)
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(moment.header)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.legendary)
                        .lineLimit(1)
                        .widgetAccentable()
                    Spacer(minLength: 0)
                    Text(moment.emoji)
                        .font(DSFont.title)
                    caption(color: DSColor.textPrimary)
                }
                .padding(DSSpacing.m)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // VoiceOver reads the moment once, through the link on top.
        .accessibilityHidden(true)
        // A clear link on top: on iOS 26 a Link wrapping an accented image can lose its URL.
        .overlay {
            Link(destination: moment.link) {
                Color.clear.contentShape(Rectangle())
            }
            .accessibilityLabel(moment.date.map { "\(moment.title), \($0)" } ?? moment.title)
        }
    }

    @ViewBuilder
    private func caption(color: Color) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(moment.photo == nil ? moment.title : "\(moment.emoji) \(moment.title)")
                .font(moment.date == nil ? DSFont.caption : DSFont.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(moment.date == nil ? 4 : 2)
            if let date = moment.date {
                Text(date)
                    .font(DSFont.caption)
                    .foregroundStyle(color.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(moment.photo == nil ? 0 : DSSpacing.m)
    }
}

private struct MessageTile: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            Image(systemName: "sparkles")
                .font(DSFont.title)
                .foregroundStyle(DSColor.legendary)
                .widgetAccentable()
            Spacer(minLength: 0)
            Text(text)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(DSSpacing.m)
    }
}

#Preview("Small", as: .systemSmall) {
    HomeWidget()
} timeline: {
    HomeWidgetEntry(date: .now, content: HomeWidgetPresenter().sample)
}

#Preview("Medium", as: .systemMedium) {
    HomeWidget()
} timeline: {
    HomeWidgetEntry(date: .now, content: HomeWidgetPresenter().sample)
    HomeWidgetEntry(date: .now, content: HomeWidgetPresenter().content(for: nil, showsPhoto: true))
}
