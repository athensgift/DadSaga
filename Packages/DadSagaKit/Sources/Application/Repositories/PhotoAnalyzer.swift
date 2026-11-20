import Domain
import Foundation

/// Port for looking at a photo on the device (ADR-0047): nothing it finds is stored, shown or sent. Each answer is
/// empty, or `nil`, when the device can't tell; it never throws.
public protocol PhotoAnalyzer: Sendable {
    /// How memorable the photo looks.
    func rating(of imageData: Data) async -> PhotoRating?
    /// The faces in the photo, and whether each looks like a child's.
    func faces(in imageData: Data) async -> [PhotoFace]
    /// What draws the eye in a photo.
    func salientObjects(in imageData: Data) async -> [PhotoRegion]
}
