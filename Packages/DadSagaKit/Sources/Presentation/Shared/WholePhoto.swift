import DesignSystem
import SwiftUI

/// A photo shown whole, never cropped: as wide as it can be, in its own shape kept between 4:5 (portrait) and 16:9
/// (landscape). A photo taller or wider than that is fitted inside, over a blurred copy of itself.
struct WholePhoto: View {
    /// The shapes the frame may take, as width over height.
    static let frameRatios: ClosedRange<CGFloat> = (4.0 / 5.0)...(16.0 / 9.0)

    let source: PhotoSource
    let loader: PhotoLoader

    @State private var photo: DecodedImage?
    @State private var maxPixelSize = 0
    @Environment(\.displayScale) private var displayScale

    private struct Request: Equatable {
        let source: PhotoSource
        let maxPixelSize: Int
    }

    /// The frame for a photo of this shape; 4:3 until the photo has loaded.
    static func frameRatio(for aspectRatio: CGFloat?) -> CGFloat {
        guard let aspectRatio else { return 4.0 / 3.0 }
        return min(max(aspectRatio, frameRatios.lowerBound), frameRatios.upperBound)
    }

    var body: some View {
        let scale = displayScale
        Color.clear
            .aspectRatio(Self.frameRatio(for: photo?.aspectRatio), contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(DSColor.surface)
            // Two overlays, not one: together, the filled copy would size the stack and the fitted photo with it.
            .overlay {
                photo?.image
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 24, opaque: true)
            }
            .clipped()
            // Clipping only hides the filled copy's overflow; taps beside the frame, on the note above, say, stay
            // theirs.
            .contentShape(.rect)
            .overlay {
                photo?.image
                    .resizable()
                    .scaledToFit()
            }
            // The longest side the photo can take: the width, or the height of the tallest frame.
            .onGeometryChange(for: Int.self) { [scale] proxy in
                Int((proxy.size.width / Self.frameRatios.lowerBound * scale).rounded(.up))
            } action: { maxPixelSize = $0 }
            .task(id: Request(source: source, maxPixelSize: maxPixelSize)) {
                guard maxPixelSize > 0 else { return }
                let data: Data? = switch source {
                case .data(let data): data
                case .stored(let id): await loader(id, maxPixelSize)
                }
                var decoded: DecodedImage?
                if let data { decoded = await DecodedImage.decode(data, maxPixelSize: maxPixelSize) }
                // A newer request (another size or photo) has started: its result wins.
                guard !Task.isCancelled else { return }
                photo = decoded
            }
    }
}
