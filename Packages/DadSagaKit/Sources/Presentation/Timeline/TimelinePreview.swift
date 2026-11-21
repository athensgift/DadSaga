import DesignSystem
import SwiftUI

extension TimelineContent {
    /// The entry shown above the fold on an iPhone Duo half-open like a laptop (ADR-0043): the one the dad tapped,
    /// or the newest while he has tapped none or the one he tapped is gone (deleted, or another child's).
    func previewed(id: UUID?) -> TimelineItem? {
        let items = sections.flatMap(\.items)
        return items.first { $0.id == id } ?? items.first
    }
}

extension TimelineItem.Kind {
    var tint: Color {
        switch self {
        case .quest: DSColor.accent
        case .boss: DSColor.boss
        case .moment: DSColor.legendary
        }
    }
}

/// One entry, large, above the fold: its cover whole beside its title and words, and a way into its note and photos.
struct TimelinePreview: View {
    let item: TimelineItem
    let editTitle: String
    let loader: PhotoLoader
    let onShowPhotos: () -> Void
    let onEdit: () -> Void

    /// The cover's height where the pane scrolls: at text sizes too large for the pane.
    private static let scrollingCoverHeight: CGFloat = 200
    /// The least height the cover is worth showing at.
    private static let smallestCoverHeight: CGFloat = 120

    var body: some View {
        // The cover takes the pane's height, so it shows whole whatever its shape. Only when the words are too
        // large for the pane does it scroll, with a smaller cover.
        ViewThatFits(in: .vertical) {
            content(coverHeight: nil)
            ScrollView { content(coverHeight: Self.scrollingCoverHeight) }
                .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func content(coverHeight: CGFloat?) -> some View {
        AdaptiveStack(alignment: .center, spacing: DSSpacing.l) {
            if let cover = item.photoIDs.first {
                JournalCover(source: .stored(cover), loader: loader, onOpen: onShowPhotos)
                    .frame(maxWidth: .infinity)
                    // With no fixed height the cover asks for little, so a tall photo never makes the pane look
                    // too small for it, and then takes whatever height the pane has.
                    .frame(
                        minHeight: coverHeight ?? Self.smallestCoverHeight,
                        idealHeight: coverHeight ?? Self.smallestCoverHeight,
                        maxHeight: coverHeight ?? .infinity
                    )
            }
            VStack(alignment: .leading, spacing: DSSpacing.s) {
                CardTitle(item.title, tint: item.kind.tint)
                Text(item.subtitle)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(editTitle, systemImage: "square.and.pencil", action: onEdit)
                    .buttonStyle(.glass)
                    .padding(.top, DSSpacing.s)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: item.photoIDs.isEmpty ? readableWidth : .infinity)
        .padding(DSSpacing.m)
        .frame(maxWidth: .infinity)
    }
}
