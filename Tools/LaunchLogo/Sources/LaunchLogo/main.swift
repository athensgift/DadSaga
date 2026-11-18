import AppKit
import SwiftUI
// The figures are internal: drawing them directly gives the rest pose without the avatars' appear animation.
@testable import DesignSystem

/// Super Dad with a smiling baby, laid out like the home screen's family (child canvas at 0.62 of the dad's height),
/// a little closer together so the pair reads as one picture.
struct LaunchFamily: View {
    let heroHeight: CGFloat

    var body: some View {
        let childHeight = heroHeight * 0.62
        HStack(alignment: .bottom, spacing: -heroHeight * 0.24) {
            HeroFigure(style: .hero, pose: .rest, isCheering: false)
                .environment(\.avatarSkin, .mediumLight)
                .scaleEffect(heroHeight / HeroFigure.designSize.height)
                .frame(width: heroHeight * HeroAvatar.aspectRatio, height: heroHeight)
                .zIndex(1)
            ChildFigure(stage: .baby, gender: .boy, traits: .smile, pose: .rest, isCheering: false)
                .environment(\.avatarSkin, .mediumLight)
                .scaleEffect(childHeight / ChildFigure.designSize.height)
                .frame(width: childHeight * ChildAvatar.aspectRatio, height: childHeight)
                .padding(
                    .bottom,
                    HeroAvatar.groundInset(forSize: heroHeight) - ChildAvatar.groundInset(forSize: childHeight)
                )
        }
    }
}

/// Crops transparent margins so the launch screen centres on the figures themselves.
func trimmed(_ image: CGImage) -> CGImage? {
    let width = image.width, height = image.height
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
              data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ),
          let data = context.data else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
    var minX = width, minY = height, maxX = -1, maxY = -1
    for row in 0..<height {
        for column in 0..<width where pixels[(row * width + column) * 4 + 3] > 8 {
            minX = min(minX, column); maxX = max(maxX, column); minY = min(minY, row); maxY = max(maxY, row)
        }
    }
    guard maxX >= minX else { return nil }
    return image.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
}

let output = URL(fileURLWithPath: "App/Resources/Assets.xcassets/LaunchLogo.imageset", isDirectory: true)
/// One rendering pass per launch appearance: the asset name suffix and the colour scheme to draw in.
let appearances: [(name: String, scheme: ColorScheme)] = [("light", .light), ("dark", .dark)]
for entry in appearances {
    NSAppearance(named: entry.scheme == .dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
        MainActor.assumeIsolated {
            for scale in [2, 3] {
                let renderer = ImageRenderer(
                    content: LaunchFamily(heroHeight: 340).environment(\.colorScheme, entry.scheme)
                )
                renderer.scale = CGFloat(scale)
                guard let image = renderer.cgImage.flatMap(trimmed),
                      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                    fatalError("Could not render the \(entry.name) launch image")
                }
                let file = output.appendingPathComponent("LaunchLogo-\(entry.name)@\(scale)x.png")
                do {
                    try png.write(to: file)
                } catch {
                    fatalError("Could not write \(file.path): \(error)")
                }
                print("Wrote \(file.lastPathComponent) (\(image.width)×\(image.height))")
            }
        }
    }
}
