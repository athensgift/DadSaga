import DesignSystem
import SwiftUI

/// Loads a moment's photo from the device by id, no larger than `maxPixelSize` on its longest side.
typealias PhotoLoader = (_ id: String, _ maxPixelSize: Int) async -> Data?

/// A moment's photo, filling its frame. Shows the placeholder until it loads, or if it is missing.
/// Loads it only as large as the frame it fills, so a small row never decodes the full photo.
struct MomentPhoto<Placeholder: View>: View {
    let photoID: String?
    let loader: PhotoLoader
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: Image?
    @State private var maxPixelSize = 0
    @Environment(\.displayScale) private var displayScale

    private struct Request: Equatable {
        let photoID: String?
        let maxPixelSize: Int
    }

    var body: some View {
        // Read here, on the main actor: the geometry closure runs off it and must not touch the view.
        let scale = displayScale
        ZStack {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .onGeometryChange(for: Int.self) { [scale] proxy in
            Int((max(proxy.size.width, proxy.size.height) * scale).rounded(.up))
        } action: { maxPixelSize = $0 }
        .task(id: Request(photoID: photoID, maxPixelSize: maxPixelSize)) {
            guard let photoID else {
                image = nil
                return
            }
            guard maxPixelSize > 0 else { return }
            guard let data = await loader(photoID, maxPixelSize) else {
                image = nil
                return
            }
            let decoded = await DecodedImage.decode(data, maxPixelSize: maxPixelSize)
            guard !Task.isCancelled else { return }
            image = decoded?.image
        }
    }
}

/// A captured moment as a gold card: the photo (or a star) and what happened.
struct MomentCard: View {
    let card: MomentCardModel
    let loader: PhotoLoader

    var body: some View {
        AdaptiveStack(alignment: .top, spacing: DSSpacing.m) {
            if card.photoID == nil {
                IconTile(symbol: "star.fill", tint: DSColor.legendary)
            } else {
                MomentPhoto(photoID: card.photoID, loader: loader) { DSColor.legendary.opacity(0.2) }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
                    .accessibilityHidden(true)
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
        .accessibilityElement(children: .combine)
    }
}
