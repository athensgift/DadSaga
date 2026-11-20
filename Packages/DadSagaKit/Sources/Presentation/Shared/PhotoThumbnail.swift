import DesignSystem
import SwiftUI

/// Loads a stored photo by id, no larger than `maxPixelSize` on its longest side.
typealias PhotoLoader = (_ id: String, _ maxPixelSize: Int) async -> Data?

/// A photo filling its frame. Shows the placeholder until it loads, or if it is missing. Decodes it only as large as
/// it fills the frame, off the main actor, so a small square never holds a full photo.
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
                Group {
                    if let image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholder()
                    }
                }
                // Measured filled, not the frame: a photo filling a square needs its shortest side at the frame's,
                // so its longest side, what the loader limits, runs past it. The frame first, then the photo's size.
                .onGeometryChange(for: Int.self) { [scale] proxy in
                    Int((max(proxy.size.width, proxy.size.height) * scale).rounded(.up))
                } action: { maxPixelSize = $0 }
            }
            .clipped()
            .contentShape(.rect)
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
                    HStack(spacing: 2) {
                        Image(systemName: "square.stack.fill")
                        Text(verbatim: "\(photoIDs.count)")
                    }
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.6), in: Capsule())
                        .padding(3)
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
