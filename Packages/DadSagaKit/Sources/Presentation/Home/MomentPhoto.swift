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
        ZStack {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .onGeometryChange(for: Int.self) { proxy in
            Int((max(proxy.size.width, proxy.size.height) * displayScale).rounded(.up))
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
            image = Image(imageData: data)
        }
    }
}

/// A captured moment as a gold card: the photo (or a star) and what happened.
struct MomentCard: View {
    let card: MomentCardModel
    let loader: PhotoLoader

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.m) {
            MomentPhoto(photoID: card.photoID, loader: loader) {
                Image(systemName: "star.fill")
                    .font(DSFont.tileSymbol)
                    .foregroundStyle(DSColor.heroHighlight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DSColor.legendary.gradient)
            }
            .frame(width: card.photoID == nil ? 36 : 64, height: card.photoID == nil ? 36 : 64)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.s) {
                    Text(card.title)
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                    Spacer(minLength: 0)
                    Text(card.badge)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.legendary)
                        .lineLimit(1)
                        .fixedSize()
                }
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
