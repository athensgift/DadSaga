import CoreGraphics
import CoreImage.CIFilterBuiltins
import CoreVideo

/// A clip with its images loaded and its overlay placed in the frame, ready to draw.
struct Shot {
    let clip: FilmClip
    /// The photo, or nil for a clip of one colour.
    let picture: CIImage?
    let overlay: CIImage?
}

/// An earlier frame that a clip's first frames dissolve in from, and how far the dissolve has come, from 0 to 1.
struct FadeIn {
    let frame: CVReadOnlyPixelBuffer
    let progress: Double
}

/// Draws one frame with Core Image: the picture placed by the camera, the overlay on top, and a dissolve from the
/// previous clip. One `CIContext` per film; filters are made per frame, since they are not `Sendable`.
struct FrameCompositor: Sendable {
    let spec: FilmSpec
    let context = CIContext(options: [.cacheIntermediates: false, .name: "FilmKit"])

    var frameRect: CGRect {
        CGRect(x: 0, y: 0, width: spec.width, height: spec.height)
    }

    func shot(of clip: FilmClip, picture: CGImage?, overlay: CGImage?) -> Shot {
        Shot(clip: clip, picture: picture.map { CIImage(cgImage: $0) }, overlay: overlay.map(placed(overlay:)))
    }

    /// Frame `local` of the shot's clip, counted from 0.
    func frame(of shot: Shot, local: Int) -> CIImage {
        let clip = shot.clip
        var image = solid(clip.picture.backdrop)
        if let picture = shot.picture {
            image = place(picture, fit: clip.fit, camera: camera(of: clip, at: local))
        }
        if let overlay = shot.overlay {
            image = overlay.composited(over: image)
        }
        return image.cropped(to: frameRect)
    }

    /// Draws `image` into `buffer`, opaque, tagged BT.709; with `fade`, dissolving in from that earlier frame.
    func render(_ image: CIImage, fade: FadeIn?, into buffer: CVPixelBuffer) {
        guard let fade else { return render(image, into: buffer) }
        // The earlier frame is only borrowed here, and the drawing is over before it is given back.
        fade.frame.withUnsafeBuffer { earlier in
            let filter = CIFilter.dissolveTransition()
            filter.inputImage = CIImage(cvPixelBuffer: earlier)
            filter.targetImage = image
            filter.time = Float(min(1, max(0, fade.progress)))
            render(filter.outputImage ?? image, into: buffer)
        }
    }

    /// The buffer is tagged first, and Core Image then draws in the colour space those tags stand for: the one a
    /// player will assume, and the one a frame is read back in for a fade. `CGColorSpace.itur_709` is not that space;
    /// its curve is steeper, and a film drawn with it plays back washed out.
    private func render(_ image: CIImage, into buffer: CVPixelBuffer) {
        let tags = [
            kCVImageBufferColorPrimariesKey: kCVImageBufferColorPrimaries_ITU_R_709_2,
            kCVImageBufferTransferFunctionKey: kCVImageBufferTransferFunction_ITU_R_709_2,
            kCVImageBufferYCbCrMatrixKey: kCVImageBufferYCbCrMatrix_ITU_R_709_2
        ]
        CVBufferSetAttachments(buffer, tags as CFDictionary, .shouldPropagate)
        context.render(image.composited(over: solid(.black)).cropped(to: frameRect), to: buffer)
    }

    /// The overlay where it is drawn. At the film's size it is left pixel for pixel; any other size is scaled evenly
    /// to fit inside the frame and centred, so a card of another shape is never stretched.
    private func placed(overlay: CGImage) -> CIImage {
        let image = CIImage(cgImage: overlay)
        let size = image.extent.size
        guard size.width > 0, size.height > 0, size != frameRect.size else { return image }
        let scale = min(frameRect.width / size.width, frameRect.height / size.height)
        let moveX = (frameRect.width - size.width * scale) / 2
        let moveY = (frameRect.height - size.height * scale) / 2
        return image
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: moveX, y: moveY))
    }

    private func solid(_ color: FilmColor) -> CIImage {
        CIImage(color: CIColor(red: color.red, green: color.green, blue: color.blue)).cropped(to: frameRect)
    }

    private func camera(of clip: FilmClip, at local: Int) -> FilmCamera {
        guard case .kenBurns(let start, let end) = clip.motion else { return FilmCamera() }
        let linear = clip.frames > 1 ? Double(local) / Double(clip.frames - 1) : 0
        let eased = linear * linear * (3 - 2 * linear)
        func blend(_ first: Double, _ last: Double) -> Double { first + (last - first) * eased }
        return FilmCamera(
            zoom: blend(start.zoom, end.zoom),
            centerX: blend(start.centerX, end.centerX),
            centerY: blend(start.centerY, end.centerY)
        )
    }

    private func place(_ image: CIImage, fit: FilmFit, camera: FilmCamera) -> CIImage {
        switch fit {
        case .fill:
            return transform(image, scale: coverScale(of: image) * camera.zoom, camera: camera, clamped: true)
        case .fitOverBlur:
            let width = CGFloat(spec.width)
            let background = transform(image, scale: coverScale(of: image), camera: FilmCamera(), clamped: true)
                .clampedToExtent()
                .applyingGaussianBlur(sigma: width * 0.04)
                .applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey: -0.12])
                .cropped(to: frameRect)
            let fitScale = min(width / image.extent.width, CGFloat(spec.height) / image.extent.height)
            return transform(image, scale: fitScale * camera.zoom, camera: camera, clamped: false)
                .composited(over: background)
                .cropped(to: frameRect)
        }
    }

    private func coverScale(of image: CIImage) -> CGFloat {
        max(CGFloat(spec.width) / image.extent.width, CGFloat(spec.height) / image.extent.height)
    }

    /// Scales `image` and moves the camera's point of it to the frame's centre. When `clamped`, the picture keeps
    /// covering the frame instead of showing an edge.
    private func transform(_ image: CIImage, scale: CGFloat, camera: FilmCamera, clamped: Bool) -> CIImage {
        let width = CGFloat(spec.width)
        let height = CGFloat(spec.height)
        let scaledWidth = image.extent.width * scale
        let scaledHeight = image.extent.height * scale
        var moveX = width / 2 - CGFloat(camera.centerX) * scaledWidth
        var moveY = height / 2 - CGFloat(1 - camera.centerY) * scaledHeight
        if clamped {
            moveX = min(0, max(width - scaledWidth, moveX))
            moveY = min(0, max(height - scaledHeight, moveY))
        }
        return image
            .transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: moveX, y: moveY))
    }
}
