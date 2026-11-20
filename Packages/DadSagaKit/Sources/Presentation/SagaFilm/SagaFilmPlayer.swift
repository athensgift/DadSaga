import AVKit
import CoreTransferable
import DesignSystem
import SwiftUI
import UniformTypeIdentifiers

/// The made film (ADR-0037 §4): it plays at once, and sharing is offered only here, next to it. The player uses the
/// default audio session, so the silent switch is respected.
struct SagaFilmPlayer: View {
    let made: SagaFilmMade
    let onMakeAnother: () -> Void
    @State private var player: AVPlayer?

    /// The most of the sheet's height the film takes, so sharing stays on screen under a vertical film.
    private static let filmHeightShare = 0.58

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: DSSpacing.m) {
                    film(in: proxy.size)
                    ShareLink(
                        item: SagaFilmFile(url: made.url),
                        preview: SharePreview(made.title, image: Image(systemName: "film"))
                    ) {
                        Label(made.shareTitle, systemImage: "square.and.arrow.up")
                            .font(DSFont.headline)
                            .onTintLabel()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    Text(made.note)
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(made.anotherTitle, action: onMakeAnother)
                        .buttonStyle(.glass)
                        .font(DSFont.body)
                }
                .frame(maxWidth: readableWidth)
                .padding(DSSpacing.m)
                .frame(maxWidth: .infinity)
            }
        }
        .task(id: made.url) {
            let player = AVPlayer(url: made.url)
            self.player = player
            player.play()
        }
        .onDisappear { player?.pause() }
    }

    /// The film in its own shape, as wide as the sheet allows without growing past its share of the height.
    private func film(in size: CGSize) -> some View {
        let ratio = made.format.aspectRatio
        let width = max(0, min(size.width - 2 * DSSpacing.m, readableWidth, size.height * Self.filmHeightShare * ratio))
        return VideoPlayer(player: player)
            .frame(width: width, height: width / ratio)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
    }
}

/// The film as the share sheet takes it: an MPEG-4 file, so "Save Video", Messages and AirDrop are offered, and each
/// receives the system's own copy (ADR-0037 §4).
struct SagaFilmFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .mpeg4Movie) { SentTransferredFile($0.url) }
    }
}
