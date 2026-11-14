import DesignSystem
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Loads a moment's photo from the device by id.
typealias PhotoLoader = (_ id: String) async -> Data?

extension Image {
    /// An image from encoded data (JPEG, HEIC, PNG…), or `nil` if it cannot be decoded.
    init?(imageData: Data) {
        #if canImport(UIKit)
        guard let image = UIImage(data: imageData) else { return nil }
        self.init(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: imageData) else { return nil }
        self.init(nsImage: image)
        #endif
    }
}

/// A moment's photo, filling its frame. Shows the placeholder until it loads, or if it is missing.
struct MomentPhoto<Placeholder: View>: View {
    let photoID: String?
    let loader: PhotoLoader
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: Image?

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
        .task(id: photoID) {
            guard let photoID, let data = await loader(photoID) else {
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
                    .font(.system(.body, weight: .semibold))
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
