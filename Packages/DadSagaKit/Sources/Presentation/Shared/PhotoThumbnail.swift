import DesignSystem
import SwiftUI

/// Loads a stored photo by id, no larger than `maxPixelSize` on its longest side.
typealias PhotoLoader = (_ id: String, _ maxPixelSize: Int) async -> Data?

/// A photo filling its frame. Shows the placeholder until it loads, or if it is missing. Decodes it only about as
/// large as it fills the frame, off the main actor, so a small square never holds a full photo.
struct SquarePhoto<Placeholder: View>: View {
    let source: PhotoSource?
    let loader: PhotoLoader
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: Image?
    @State private var maxPixelSize = 0
    @Environment(\.displayScale) private var displayScale

    private struct Request: Equatable {
        let source: PhotoSource?
        let maxPixelSize: Int
    }

    var body: some View {
        // Read here, on the main actor: the geometry closure runs off it and must not touch the view.
        let scale = displayScale
        // The frame is the one it is given; the photo fills it and stops at its edges, in what it draws and in what it
        // takes taps for. Clipping alone only hides the overflow: a tap beside the frame would still open the photo.
        Color.clear
            .overlay {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder()
                }
            }
            .clipped()
            .contentShape(.rect)
            // The frame, measured once: the size asked for never depends on the photo, so a photo loads once.
            .onGeometryChange(for: Int.self) { [scale] proxy in
                PhotoFill.pixelSize(filling: proxy.size, scale: scale)
            } action: { maxPixelSize = $0 }
            .task(id: Request(source: source, maxPixelSize: maxPixelSize)) {
                guard maxPixelSize > 0 else { return }
                let data: Data? = switch source {
                case .stored(let id): await loader(id, maxPixelSize)
                case .data(let data): data
                case nil: nil
                }
                var decoded: DecodedImage?
                if let data { decoded = await DecodedImage.decode(data, maxPixelSize: maxPixelSize) }
                guard !Task.isCancelled else { return }
                image = decoded?.image
            }
    }
}

/// How large a photo is loaded to fill a frame.
enum PhotoFill {
    /// The longest shape, as its long side over its short one, that still fills a frame at full sharpness: a phone's
    /// camera gives 4:3 and 16:9. A longer photo (a panorama) fills the frame a little soft.
    static let longestShape: CGFloat = 16.0 / 9.0

    /// The longest side to load, in pixels, for a photo filling a frame of `size` points. The loader limits a photo's
    /// longest side, and a photo filling a frame needs its shortest side at the frame's longest; its shape isn't
    /// known before it loads, so it is taken to be `longestShape`.
    static func pixelSize(filling size: CGSize, scale: CGFloat) -> Int {
        Int((max(size.width, size.height) * scale * longestShape).rounded(.up))
    }
}

/// An entry's cover as a small rounded square, with how many photos it has when there are several (ADR-0042 §4).
/// Decorative to VoiceOver: the card or row around it says how many photos there are.
struct PhotoThumbnail: View {
    let photoIDs: [String]
    let loader: PhotoLoader
    var size: CGFloat = 64
    /// Shown until the photo loads.
    var placeholder: Color = DSColor.legendary.opacity(0.2)

    var body: some View {
        SquarePhoto(source: photoIDs.first.map(PhotoSource.stored), loader: loader) { placeholder }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if photoIDs.count > 1 {
                    HStack(spacing: DSSpacing.xxs) {
                        Image(systemName: "square.stack.fill")
                        Text(verbatim: "\(photoIDs.count)")
                    }
                        .font(DSFont.badge)
                        .monospacedDigit()
                        .foregroundStyle(DSColor.onPhoto)
                        .padding(.horizontal, DSSpacing.xs)
                        .padding(.vertical, DSSpacing.xxs)
                        .background(DSColor.photoLabelGround, in: Capsule())
                        .padding(DSSpacing.xxs)
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - A thumbnail on a card that does something else when tapped

/// Where a card's thumbnail goes: kept free in the card's own button, so the thumbnail can be a button beside it
/// rather than inside it, where it would never get its own taps (ADR-0042 §4).
struct ThumbnailSlot: View {
    var size: CGFloat = 64

    var body: some View {
        Color.clear
            .frame(width: size, height: size)
            .anchorPreference(key: ThumbnailSlotKey.self, value: .bounds) { $0 }
            .accessibilityHidden(true)
    }
}

private struct ThumbnailSlotKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

extension View {
    /// Puts `thumbnail` exactly over the `ThumbnailSlot` inside this view, whatever the layout.
    func thumbnail<Thumbnail: View>(@ViewBuilder _ thumbnail: @escaping () -> Thumbnail) -> some View {
        overlayPreferenceValue(ThumbnailSlotKey.self) { anchor in
            if let anchor {
                GeometryReader { proxy in
                    let frame = proxy[anchor]
                    thumbnail()
                        .frame(width: frame.width, height: frame.height)
                        .offset(x: frame.minX, y: frame.minY)
                }
            }
        }
    }
}
