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
