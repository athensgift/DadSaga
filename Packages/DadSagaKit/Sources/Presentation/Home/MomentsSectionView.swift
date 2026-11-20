import DesignSystem
import SwiftUI

/// The selected child's legendary moments: gold cards, newest first, and a button to capture one.
struct MomentsSectionView: View {
    let section: MomentsSection
    let loader: PhotoLoader
    let onAdd: () -> Void
    let onEdit: (UUID) -> Void
    let onShowPhotos: (MomentCardModel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.title)
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(section.progress)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.legendary)
                    .monospacedDigit()
                Spacer()
                if !section.isComplete {
                    Button(section.addTitle, systemImage: "plus", action: onAdd)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)
                        .tint(DSColor.legendary)
                }
            }
            if section.cards.isEmpty {
                Button(action: onAdd) {
                    Label(section.emptyText, systemImage: "sparkles")
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DSSpacing.m)
                        .background {
                            RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                                .strokeBorder(DSColor.legendary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        }
                }
                .buttonStyle(.plain)
            }
            ForEach(section.cards) { card in
                MomentCard(
                    card: card,
                    showPhotosTitle: section.viewer.showPhotos,
                    loader: loader,
                    onEdit: { onEdit(card.id) },
                    onShowPhotos: { onShowPhotos(card) }
                )
            }
        }
    }
}

/// A captured moment as a gold card: the cover (or a star) and what happened. Tapping the card edits the moment;
/// tapping its photo shows the photos full screen (ADR-0042 §4). One element to VoiceOver, with "Show photos" as an
/// action.
struct MomentCard: View {
    let card: MomentCardModel
    let showPhotosTitle: String
    let loader: PhotoLoader
    let onEdit: () -> Void
    let onShowPhotos: () -> Void

    var body: some View {
        Button(action: onEdit) {
            AdaptiveStack(alignment: .top, spacing: DSSpacing.m) {
                if card.photoIDs.isEmpty {
                    IconTile(symbol: "star.fill", tint: DSColor.legendary)
                } else {
                    ThumbnailSlot()
                }
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    CardTitle(card.title, badge: card.badge, tint: DSColor.legendary)
                    Text(card.subtitle)
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DSSpacing.m)
            .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(card.photoCount ?? "")
        .accessibilityActions {
            if !card.photoIDs.isEmpty {
                Button(showPhotosTitle, action: onShowPhotos)
            }
        }
        // Beside the card's button, not inside it, so it gets its own taps.
        .thumbnail {
            Button(action: onShowPhotos) {
                PhotoThumbnail(photoIDs: card.photoIDs, loader: loader)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
    }
}
