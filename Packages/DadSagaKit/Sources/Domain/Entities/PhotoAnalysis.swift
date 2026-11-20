import Foundation

/// How memorable a photo looks, as the device's own model rates it (ADR-0047 §2). It only chooses among the further
/// photos of one entry, for one film: never shown, stored or compared across entries (ADR-0006).
public struct PhotoRating: Hashable, Sendable {
    /// From -1, least memorable, to 1.
    public let score: Double
    /// A screenshot, a receipt, a document: not necessarily poor, but not a moment.
    public let isUtility: Bool

    public init(score: Double, isUtility: Bool) {
        self.score = score
        self.isUtility = isUtility
    }
}

/// A part of a photo in unit coordinates: (0, 0) is its top left and (1, 1) its bottom right.
public struct PhotoRegion: Hashable, Sendable {
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

    public var right: Double { left + width }
    public var bottom: Double { top + height }

    /// The smallest region holding both.
    public func union(_ other: PhotoRegion) -> PhotoRegion {
        let unionLeft = min(left, other.left)
        let unionTop = min(top, other.top)
        return PhotoRegion(
            left: unionLeft,
            top: unionTop,
            width: max(right, other.right) - unionLeft,
            height: max(bottom, other.bottom) - unionTop
        )
    }

    /// Grown by `share` of its own size on every side, then kept inside the photo.
    func grown(by share: Double) -> PhotoRegion {
        let grownLeft = max(0, left - width * share)
        let grownTop = max(0, top - height * share)
        return PhotoRegion(
            left: grownLeft,
            top: grownTop,
            width: min(1, right + width * share) - grownLeft,
            height: min(1, bottom + height * share) - grownTop
        )
    }
}

/// A face the device found in a photo: where it is, and whether it looks like a child's. Never who it is.
public struct PhotoFace: Hashable, Sendable {
    public let region: PhotoRegion
    /// `nil` when the device couldn't tell.
    public let isChild: Bool?

    public init(region: PhotoRegion, isChild: Bool?) {
        self.region = region
        self.isChild = isChild
    }
}

/// Where a saga film's camera goes in a photo, and whether it goes to a child (ADR-0047 §3).
public struct PhotoFraming: Hashable, Sendable {
    public let region: PhotoRegion
    /// A child was found: the camera always moves in on them, never away.
    public let showsChild: Bool

    public init(region: PhotoRegion, showsChild: Bool) {
        self.region = region
        self.showsChild = showsChild
    }
}

/// What the camera of a saga film looks at in a photo (ADR-0047 §3). Pure and deterministic.
public enum PhotoSubject {
    /// Faces under this share of the tallest face's height, of all the faces found, are in the background, and left
    /// out, a child's too.
    static let backgroundShare = 1.0 / 3
    /// How much a face grows on every side: hair, chin and a little air around it.
    static let faceMargin = 0.35

    /// The children's faces as one region; all faces when none looks like a child; the salient objects when there is
    /// no face; `nil` when there is neither. Faces in the background count for neither.
    public static func region(faces: [PhotoFace], salientObjects: [PhotoRegion]) -> PhotoRegion? {
        framing(faces: faces, salientObjects: salientObjects)?.region
    }

    /// The subject's region, and whether it is a child's; `nil` when there is no subject.
    public static func framing(faces: [PhotoFace], salientObjects: [PhotoRegion]) -> PhotoFraming? {
        let tallest = faces.map(\.region.height).max() ?? 0
        let near = faces.filter { $0.region.height >= tallest * backgroundShare }
        let children = near.filter { $0.isChild == true }
        let pool = children.isEmpty ? near : children
        let subject = pool.map { $0.region.grown(by: faceMargin) }.reduce(nil) { $0?.union($1) ?? $1 }
        if let subject {
            return PhotoFraming(region: subject, showsChild: !children.isEmpty)
        }
        return salientObjects.reduce(nil) { $0?.union($1) ?? $1 }.map { PhotoFraming(region: $0, showsChild: false) }
    }
}
