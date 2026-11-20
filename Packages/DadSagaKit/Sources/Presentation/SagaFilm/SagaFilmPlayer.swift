import AVKit
import CoreTransferable
import DesignSystem
import SwiftUI
import UniformTypeIdentifiers

/// The made film (ADR-0037 §4): it plays at once, and sharing is offered only here, next to it. The player uses the
/// default audio session, so the silent switch is respected.
///
/// The film stays in place and what goes with it scrolls under it. On an iPhone Duo half-open like a laptop the film
/// stands above the fold and the rest lies below it (ADR-0043); the same player is moved, so the film plays on.
struct SagaFilmPlayer: View {
    let made: SagaFilmMade
    let onMakeAnother: () -> Void
    @State private var player: AVPlayer?
    @State private var size = CGSize.zero
    @State private var fold: HorizontalFold?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The most of the sheet's height the film takes, so sharing stays on screen under a vertical film.
    private static let filmHeightShare = 0.58

    /// The film in its own shape. Flat: as wide as the sheet allows without growing past its share of the height.
    /// Above a fold: as large as fits there.
    static func filmSize(aspectRatio: Double, in size: CGSize, fold: HorizontalFold?) -> CGSize {
        let widest = size.width - 2 * DSSpacing.m
        let width = if let fold {
            min(widest, (fold.top - 2 * DSSpacing.m) * aspectRatio)
        } else {
            min(widest, readableWidth, size.height * filmHeightShare * aspectRatio)
        }
        return CGSize(width: max(0, width), height: max(0, width) / aspectRatio)
    }

    var body: some View {
        let panes = fold.map { AnyLayout(FoldedStackLayout(fold: $0)) } ?? AnyLayout(VStackLayout(spacing: 0))
        panes {
            film
            ScrollView {
                VStack(spacing: DSSpacing.m) {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Read where the panes are placed, so the fold is in their coordinates.
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onHorizontalFoldChange(minimumPaneHeight: foldPaneMinimum) { fold = $0 }
        .animation(reduceMotion ? nil : .smooth, value: fold)
        .task(id: made.url) {
            let player = AVPlayer(url: made.url)
            self.player = player
            player.play()
        }
        .onDisappear { player?.pause() }
    }

    private var film: some View {
        let filmSize = Self.filmSize(aspectRatio: made.format.aspectRatio, in: size, fold: fold)
        return VideoPlayer(player: player)
            .frame(width: filmSize.width, height: filmSize.height)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
            .padding(.top, fold == nil ? DSSpacing.m : 0)
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
