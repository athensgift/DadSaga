#if os(iOS)
import SwiftUI
import UIKit

/// One photo that can be pinched or double-tapped up to 4×, and swiped down to close while it is not zoomed in.
/// SwiftUI has no pinch-to-zoom for a scroll view and no way to keep a zoomed photo from closing (ADR-0042 §4), so
/// this wraps a `UIScrollView`. It reports its zoom through `onZoomChange` and never writes a binding while updating.
struct ZoomablePhoto: UIViewRepresentable {
    let image: CGImage?
    /// The page shown. A page swiped away goes back to the smallest zoom, so the viewer's state stays in step.
    let isCurrent: Bool
    /// Changes whenever VoiceOver's zoom action asks for a step in or out.
    let zoomRequest: ZoomRequest
    let onZoomChange: (_ isZoomedIn: Bool) -> Void
    let onSwipeDown: () -> Void

    struct ZoomRequest: Equatable {
        var count = 0
        var zoomIn = true

        mutating func next(zoomIn: Bool) {
            count += 1
            self.zoomIn = zoomIn
        }
    }

    func makeUIView(context: Context) -> PhotoScrollView {
        let view = PhotoScrollView()
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: PhotoScrollView, context: Context) {
        view.onZoomChange = onZoomChange
        view.onSwipeDown = onSwipeDown
        if view.image !== image { view.image = image }
        if !isCurrent { view.resetZoom() }
        if view.lastZoomRequest != zoomRequest {
            let isFirst = view.lastZoomRequest == nil
            view.lastZoomRequest = zoomRequest
            if !isFirst { view.stepZoom(in: zoomRequest.zoomIn) }
        }
    }
}

/// The scroll view behind `ZoomablePhoto`: keeps the photo fitted and centred, zooms on a double tap, and follows a
/// downward swipe at the smallest zoom.
final class PhotoScrollView: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    var onZoomChange: ((Bool) -> Void)?
    var onSwipeDown: (() -> Void)?
    var lastZoomRequest: ZoomablePhoto.ZoomRequest?

    private let imageView = UIImageView()
    private var fittedForSize: CGSize = .zero
    private var isZoomedIn = false
    private lazy var swipeDown = UIPanGestureRecognizer(target: self, action: #selector(followSwipeDown(_:)))

    var image: CGImage? {
        didSet {
            imageView.image = image.map { UIImage(cgImage: $0) }
            fittedForSize = .zero
            setNeedsLayout()
        }
    }

    init() {
        super.init(frame: .zero)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 4
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(toggleZoom(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        swipeDown.delegate = self
        addGestureRecognizer(swipeDown)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != fittedForSize {
            fittedForSize = bounds.size
            fitImage()
        }
    }

    /// The photo as large as it fits, at the smallest zoom.
    private func fitImage() {
        zoomScale = minimumZoomScale
        let size = imageView.image?.size ?? .zero
        guard size.width > 0, size.height > 0, bounds.width > 0, bounds.height > 0 else {
            imageView.frame = bounds
            contentSize = bounds.size
            return
        }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        imageView.frame = CGRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale)
        contentSize = imageView.frame.size
        centreImage()
        reportZoom()
    }

    /// Keeps a photo smaller than the screen in its middle.
    private func centreImage() {
        let horizontal = max((bounds.width - contentSize.width) / 2, 0)
        let vertical = max((bounds.height - contentSize.height) / 2, 0)
        contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    /// Reported on the next turn of the main actor, never while SwiftUI is updating the view.
    private func reportZoom() {
        let zoomed = zoomScale > minimumZoomScale + 0.01
        guard zoomed != isZoomedIn else { return }
        isZoomedIn = zoomed
        Task { @MainActor [weak self] in self?.onZoomChange?(zoomed) }
    }

    func resetZoom() {
        guard zoomScale > minimumZoomScale else { return }
        setZoomScale(minimumZoomScale, animated: false)
    }

    /// One step in (to 2×, then 4×) or out, for VoiceOver's zoom action.
    func stepZoom(in zoomIn: Bool) {
        let target = zoomIn ? min(zoomScale * 2, maximumZoomScale) : max(zoomScale / 2, minimumZoomScale)
        setZoomScale(target, animated: true)
    }

    // MARK: UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centreImage()
        reportZoom()
    }

    // MARK: Gestures

    @objc private func toggleZoom(_ tap: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale {
            setZoomScale(minimumZoomScale, animated: true)
            return
        }
        let point = tap.location(in: imageView)
        let scale = maximumZoomScale / 2
        let size = CGSize(width: bounds.width / scale, height: bounds.height / scale)
        zoom(to: CGRect(origin: CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2), size: size), animated: true)
    }

    /// Only a mostly downward swipe, and only at the smallest zoom: zoomed in, a swipe moves around the photo.
    override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        guard recognizer === swipeDown else { return super.gestureRecognizerShouldBegin(recognizer) }
        let velocity = swipeDown.velocity(in: self)
        return zoomScale <= minimumZoomScale && velocity.y > abs(velocity.x)
    }

    @objc private func followSwipeDown(_ pan: UIPanGestureRecognizer) {
        let distance = max(pan.translation(in: self).y, 0)
        switch pan.state {
        case .changed:
            imageView.transform = CGAffineTransform(translationX: 0, y: distance)
            alpha = 1 - min(distance / 600, 0.5)
        case .ended where distance > 120 || pan.velocity(in: self).y > 900:
            onSwipeDown?()
        default:
            UIView.animate(withDuration: 0.25) {
                self.imageView.transform = .identity
                self.alpha = 1
            }
        }
    }
}
#endif
