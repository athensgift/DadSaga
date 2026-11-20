import DesignSystem
import SwiftUI

extension View {
    /// Shows an entry's photos full screen while `content` is set (ADR-0042 §4). Without the zoom transition, which
    /// misbehaves on iOS 26. Closing sets it back to `nil`, as does whatever closes it from outside (a link).
    func photoViewer(_ content: Binding<PhotoViewerContent?>, loader: @escaping PhotoLoader) -> some View {
        #if os(iOS)
        fullScreenCover(item: content) { shown in
            PhotoViewer(content: shown, loader: loader) { content.wrappedValue = nil }
        }
        #else
        self
        #endif
    }
}

#if os(iOS)
/// An entry's photos, full screen on black: swipe sideways between them, pinch or double-tap to zoom, swipe down or
/// Close to leave. Only the shown page and its neighbours are decoded.
struct PhotoViewer: View {
    /// The size the store keeps (ADR-0016): the viewer never asks for more.
    static let maxPixelSize = 2048

    let content: PhotoViewerContent
    let loader: PhotoLoader
    let onClose: () -> Void

    @State private var index: Int
    @State private var isZoomedIn = false

    init(content: PhotoViewerContent, loader: @escaping PhotoLoader, onClose: @escaping () -> Void) {
        self.content = content
        self.loader = loader
        self.onClose = onClose
        _index = State(initialValue: content.startIndex)
    }

    var body: some View {
        TabView(selection: $index) {
            ForEach(content.pages) { page in
                PhotoViewerPage(
                    page: page,
                    isLoaded: abs(page.id - index) <= 1,
                    loader: loader,
                    onZoomChange: { isZoomedIn = $0 },
                    onTurn: turn,
                    onClose: onClose
                )
                .tag(page.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // Zoomed in, a sideways swipe moves around the photo instead of turning the page.
        .scrollDisabled(isZoomedIn)
        .background(.black)
        .ignoresSafeArea()
        .overlay(alignment: .top) { topBar }
        .onChange(of: index) { isZoomedIn = false }
        .environment(\.colorScheme, .dark)
        .accessibilityAction(.escape, onClose)
    }

    private var topBar: some View {
        HStack {
            if let counter = content.counter(at: index) {
                Text(counter)
                    .font(DSFont.headline)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, DSSpacing.m)
                    .padding(.vertical, DSSpacing.s)
                    .glassEffect(.regular, in: Capsule())
                    // Each photo already says "Photo 2 of 5".
                    .accessibilityHidden(true)
            }
            Spacer()
            Button(content.closeTitle, systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .font(DSFont.headline)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
        }
        .padding(.horizontal, DSSpacing.m)
        .padding(.top, DSSpacing.s)
    }

    private func turn(by step: Int) {
        let next = index + step
        guard content.pages.indices.contains(next) else { return }
        withAnimation { index = next }
    }
}

/// One page of the viewer: the photo, loaded at up to 2048 px while it is near the one shown.
private struct PhotoViewerPage: View {
    let page: PhotoViewerContent.Page
    let isLoaded: Bool
    let loader: PhotoLoader
    let onZoomChange: (Bool) -> Void
    let onTurn: (Int) -> Void
    let onClose: () -> Void

    @State private var image: CGImage?
    @State private var zoomRequest = ZoomablePhoto.ZoomRequest()

    var body: some View {
        ZoomablePhoto(image: image, zoomRequest: zoomRequest, onZoomChange: onZoomChange, onSwipeDown: onClose)
            .overlay {
                if image == nil && isLoaded {
                    ProgressView().tint(.white)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(page.label)
            .accessibilityAddTraits(.isImage)
            .accessibilityZoomAction { action in
                zoomRequest.next(zoomIn: action.direction == .zoomIn)
            }
            .accessibilityScrollAction { edge in
                switch edge {
                case .trailing: onTurn(1)
                case .leading: onTurn(-1)
                default: break
                }
            }
            .task(id: isLoaded) {
                guard isLoaded else {
                    image = nil
                    return
                }
                let data: Data? = switch page.source {
                case .data(let data): data
                case .stored(let id): await loader(id, PhotoViewer.maxPixelSize)
                }
                guard let data else { return }
                let decoded = await DecodedImage.decode(data, maxPixelSize: PhotoViewer.maxPixelSize)
                guard !Task.isCancelled else { return }
                image = decoded?.cgImage
            }
    }
}
#endif
