import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public extension Image {
    /// An image from encoded data (JPEG, HEIC, PNG…), or `nil` if it cannot be decoded.
    init?(imageData: Data) {
        #if canImport(UIKit)
        guard let image = UIImage(data: imageData) else { return nil }
        self.init(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: imageData) else { return nil }
        self.init(nsImage: image)
        #endif
    }
}

/// A decoded photo and its shape, for showing it whole (its width over its height, after the photo's orientation).
public struct DecodedImage {
    public let image: Image
    public let aspectRatio: CGFloat

    /// `nil` if the data cannot be decoded or has no size.
    public init?(data: Data) {
        #if canImport(UIKit)
        guard let image = UIImage(data: data), image.size.height > 0 else { return nil }
        self.image = Image(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data), image.size.height > 0 else { return nil }
        self.image = Image(nsImage: image)
        #endif
        aspectRatio = image.size.width / image.size.height
    }
}
