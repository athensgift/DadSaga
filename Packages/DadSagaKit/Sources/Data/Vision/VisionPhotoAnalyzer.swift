import Application
import CoreGraphics
import Domain
import Foundation
import Vision

/// Looks at photos with Apple's Vision, on the device (ADR-0046). The only file that imports Vision. Each request is
/// performed on its own, so one the device can't run leaves only its own answer empty.
public struct VisionPhotoAnalyzer: PhotoAnalyzer {
    /// A face's crop for telling a child from an adult: its box grown by this share of its size on every side, so the
    /// head and shoulders are in it.
    static let ageCropMargin = 0.5
    static let childLabels: Set<String> = ["baby", "child"]
    static let adultLabels: Set<String> = ["adult", "teen"]

    public init() {}

    @concurrent
    public func rating(of imageData: Data) async -> PhotoRating? {
        guard let scores = try? await ImageRequestHandler(imageData).perform(CalculateImageAestheticsScoresRequest())
        else { return nil }
        return PhotoRating(score: Double(scores.overallScore), isUtility: scores.isUtility)
    }

    @concurrent
    public func faces(in imageData: Data) async -> [PhotoFace] {
        let handler = ImageRequestHandler(imageData)
        let boxes = ((try? await handler.perform(DetectFaceRectanglesRequest())) ?? []).map(\.boundingBox)
        var faces: [PhotoFace] = []
        for box in boxes {
            guard !Task.isCancelled else { return [] }
            faces.append(PhotoFace(region: Self.region(box), isChild: await Self.looksLikeChild(box, in: handler)))
        }
        return faces
    }

    @concurrent
    public func salientObjects(in imageData: Data) async -> [PhotoRegion] {
        let request = GenerateAttentionBasedSaliencyImageRequest()
        guard let saliency = try? await ImageRequestHandler(imageData).perform(request) else { return [] }
        return saliency.salientObjects.map { Self.region($0.boundingBox) }
    }

    /// Whether the image classifier sees more of a child than of an adult around the face; `nil` when it sees neither.
    private static func looksLikeChild(_ face: NormalizedRect, in handler: ImageRequestHandler) async -> Bool? {
        var request = ClassifyImageRequest()
        request.regionOfInterest = grown(face)
        guard let labels = try? await handler.perform(request) else { return nil }
        func confidence(_ names: Set<String>) -> Float {
            labels.filter { names.contains($0.identifier) }.reduce(0) { $0 + $1.confidence }
        }
        let child = confidence(childLabels)
        let adult = confidence(adultLabels)
        guard child > 0 || adult > 0 else { return nil }
        return child > adult
    }

    private static func grown(_ box: NormalizedRect) -> NormalizedRect {
        let rect = box.cgRect
        let grown = rect.insetBy(dx: -rect.width * ageCropMargin, dy: -rect.height * ageCropMargin)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        return NormalizedRect(normalizedRect: grown.isNull ? rect : grown)
    }

    /// Vision's box, from the lower left, as a region from the top left.
    static func region(_ box: NormalizedRect) -> PhotoRegion {
        let rect = box.cgRect
        return PhotoRegion(left: rect.minX, top: 1 - rect.maxY, width: rect.width, height: rect.height)
    }
}
