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

    var body: some View {
        // Scrolls only when the text is too large for the pane.
        ScrollView {
            AdaptiveStack(alignment: .center, spacing: DSSpacing.l) {
                if let cover = item.photoIDs.first {
                    JournalCover(source: .stored(cover), loader: loader, onOpen: onShowPhotos)
                        .frame(maxWidth: .infinity)
                }
                VStack(alignment: .leading, spacing: DSSpacing.s) {
                    CardTitle(item.title, badge: item.badge, tint: item.kind.tint)
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
        .scrollBounceBehavior(.basedOnSize)
    }
}
