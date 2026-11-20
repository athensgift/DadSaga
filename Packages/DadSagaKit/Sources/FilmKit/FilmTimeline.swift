import CoreGraphics
import Foundation

/// The film's format: its size in pixels, frame rate and bit rates. H.264 High, AAC, MP4, BT.709 (ADR-0036 §3).
///
/// The width and height must be positive and even (H.264 halves them for colour), and every rate positive; the encoder
/// refuses any other spec with `FilmError.invalidSpec`.
public struct FilmSpec: Hashable, Sendable {
    public let width: Int
    public let height: Int
    public let framesPerSecond: Int
    public let videoBitRate: Int
    public let audioSampleRate: Int
    public let audioBitRate: Int

    public init(
        width: Int,
        height: Int,
        framesPerSecond: Int = 30,
        videoBitRate: Int = 6_000_000,
        audioSampleRate: Int = 48_000,
        audioBitRate: Int = 128_000
    ) {
        self.width = width
        self.height = height
        self.framesPerSecond = framesPerSecond
        self.videoBitRate = videoBitRate
        self.audioSampleRate = audioSampleRate
        self.audioBitRate = audioBitRate
    }

    public static let vertical = FilmSpec(width: 1080, height: 1920)
    public static let wide = FilmSpec(width: 1920, height: 1080)

    var isEncodable: Bool {
        [width, height].allSatisfy { $0 > 0 && $0.isMultiple(of: 2) }
            && [framesPerSecond, videoBitRate, audioSampleRate, audioBitRate].allSatisfy { $0 > 0 }
    }
}

/// An opaque colour, components from 0 to 1.
public struct FilmColor: Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let black = FilmColor(red: 0, green: 0, blue: 0)
}

/// Where the camera looks in a picture: how far in, and the point of the picture at the frame's centre, from (0, 0)
/// at its top left to (1, 1) at its bottom right.
public struct FilmCamera: Hashable, Sendable {
    public let zoom: Double
    public let centerX: Double
    public let centerY: Double

    public init(zoom: Double = 1, centerX: Double = 0.5, centerY: Double = 0.5) {
        self.zoom = max(1, zoom)
        self.centerX = centerX
        self.centerY = centerY
    }
}

/// A part of a picture in unit coordinates, from (0, 0) at its top left to (1, 1) at its bottom right.
public struct FilmRegion: Hashable, Sendable {
    public let left: Double
    public let top: Double
    public let width: Double
    public let height: Double

    public init(left: Double, top: Double, width: Double, height: Double) {
        self.left = left
        self.top = top
        self.width = max(0, width)
        self.height = max(0, height)
    }
}

public extension FilmCamera {
    /// The closest camera on `focus`, up to `maxZoom`, that keeps all of it in the frame (ADR-0046 §3): the zoom is
    /// lowered until it fits, never below 1. Centred on the focus as far as the picture allows: on a side the picture
    /// fills, its edge never comes into the frame; on a side it doesn't, the picture stays in the middle, whole.
    ///
    /// - Parameters:
    ///   - pictureSize: the photo's size in pixels, as the clip will draw it.
    ///   - fit: how the clip fits the photo in the frame.
    static func closest(
        on focus: FilmRegion, pictureSize: CGSize, spec: FilmSpec, fit: FilmFit, maxZoom: Double
    ) -> FilmCamera {
        guard pictureSize.width > 0, pictureSize.height > 0 else { return FilmCamera() }
        let frameWidth = Double(spec.width)
        let frameHeight = Double(spec.height)
        let widthScale = frameWidth / pictureSize.width
        let heightScale = frameHeight / pictureSize.height
        let baseScale = fit == .fill ? max(widthScale, heightScale) : min(widthScale, heightScale)
        // How much of the picture the frame shows across and down, at zoom 1.
        let seenAcross = frameWidth / (pictureSize.width * baseScale)
        let seenDown = frameHeight / (pictureSize.height * baseScale)
        var zoom = maxZoom
        if focus.width > 0 { zoom = min(zoom, seenAcross / focus.width) }
        if focus.height > 0 { zoom = min(zoom, seenDown / focus.height) }
        zoom = max(1, zoom)
        return FilmCamera(
            zoom: zoom,
            centerX: center(on: focus.left, length: focus.width, seen: seenAcross / zoom),
            centerY: center(on: focus.top, length: focus.height, seen: seenDown / zoom)
        )
    }

    /// The centre along one side: the picture's middle where the frame shows all of it; otherwise the focus's middle,
    /// moved as little as keeps the picture's edges out of the frame and, as far as the zoom allows, the focus whole.
    private static func center(on start: Double, length: Double, seen: Double) -> Double {
        guard seen < 1 else { return 0.5 }
        let half = seen / 2
        let lowest = max(half, start + length - half)
        let highest = min(1 - half, start + half)
        let middle = start + length / 2
        guard lowest <= highest else { return min(1 - half, max(half, middle)) }
        return min(highest, max(lowest, middle))
    }
}

public enum FilmMotion: Hashable, Sendable {
    case still
    /// The camera glides from one view to the other over the clip, easing in and out.
    case kenBurns(start: FilmCamera, end: FilmCamera)
}

/// How a picture of another shape fills the frame.
public enum FilmFit: Hashable, Sendable {
    /// Fills the frame, cropping what doesn't fit.
    case fill
    /// Shows the whole picture over a blurred, darkened copy of itself: a portrait photo in a wide film.
    case fitOverBlur
}

/// Makes one of a clip's images when the encoder is about to need it: one clip ahead of the one being written, so at
/// most two clips' images are in memory at once. It may run on any thread, and is cancelled with the film.
public typealias FilmImageLoader = @Sendable () async throws -> CGImage

/// Makes a clip's photo, as `FilmImageLoader` makes an image: one clip ahead, on any thread, cancelled with the film.
public typealias FilmPhotoLoader = @Sendable () async throws -> FilmPhoto

/// A clip's photo, and how the clip moves now that the photo is known.
public struct FilmPhoto: Sendable {
    public let image: CGImage
    /// Replaces the clip's own motion: one that depends on the photo, such as `FilmCamera.closest(on:…)`. `nil`
    /// keeps the clip's.
    public let motion: FilmMotion?

    public init(_ image: CGImage, motion: FilmMotion? = nil) {
        self.image = image
        self.motion = motion
    }
}

/// What a clip shows under its overlay.
public enum FilmPicture: Sendable {
    case solid(FilmColor)
    /// A photo. The loader should return it upright and already scaled down to about the film's size: a `CGImage`
    /// carries no EXIF orientation, and the encoder draws every pixel it is given on every frame.
    case image(FilmPhotoLoader)

    /// What lies under the picture: the clip's colour, or black behind a photo.
    var backdrop: FilmColor {
        if case .solid(let color) = self { color } else { .black }
    }
}

public enum FilmTransition: Hashable, Sendable {
    case cut
    /// The clip's first `frames` dissolve in from the previous clip's last frame. A fade as long as the clip or longer
    /// is cut short, so the clip always ends as itself; the film's first clip has nothing to fade from.
    case crossfade(frames: Int)
}

/// One shot of the film.
public struct FilmClip: Sendable {
    public let frames: Int
    public let picture: FilmPicture
    public let fit: FilmFit
    public let motion: FilmMotion
    /// Drawn over the picture: a card's text, a title. Transparent where the picture shows. Loaded with the picture.
    ///
    /// It should be the film's size in pixels, and is then drawn pixel for pixel. Any other size is scaled evenly to
    /// fit inside the frame and centred, never stretched.
    public let overlay: FilmImageLoader?
    public let transitionIn: FilmTransition

    public init(
        frames: Int,
        picture: FilmPicture,
        fit: FilmFit = .fill,
        motion: FilmMotion = .still,
        overlay: FilmImageLoader? = nil,
        transitionIn: FilmTransition = .cut
    ) {
        self.frames = max(1, frames)
        self.picture = picture
        self.fit = fit
        self.motion = motion
        self.overlay = overlay
        self.transitionIn = transitionIn
    }

    /// The same clip, moving as `motion`.
    func moving(_ motion: FilmMotion) -> FilmClip {
        FilmClip(
            frames: frames, picture: picture, fit: fit, motion: motion, overlay: overlay, transitionIn: transitionIn
        )
    }

    /// How many of the clip's first frames dissolve in: at least its last frame is always the clip alone.
    var fadeFrames: Int {
        guard case .crossfade(let frames) = transitionIn else { return 0 }
        return min(max(0, frames), self.frames - 1)
    }
}

/// The film's soundtrack: looped or trimmed to the film's length, and faded out at its end. The fade must be a number
/// of seconds from 0 up (the encoder refuses any other with `FilmError.invalidFadeOut`); one longer than the film
/// lasts the whole film.
public struct FilmMusic: Hashable, Sendable {
    public let url: URL
    public let fadeOutSeconds: Double

    public init(url: URL, fadeOutSeconds: Double = 2) {
        self.url = url
        self.fadeOutSeconds = fadeOutSeconds
    }
}

/// Everything a film is made of. Its length is the sum of its clips' frames.
public struct FilmTimeline: Sendable {
    public let spec: FilmSpec
    public let clips: [FilmClip]
    public let music: FilmMusic?

    public init(spec: FilmSpec, clips: [FilmClip], music: FilmMusic? = nil) {
        self.spec = spec
        self.clips = clips
        self.music = music
    }

    public var frameCount: Int {
        clips.reduce(0) { $0 + $1.frames }
    }
}
