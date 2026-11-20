import AppKit
import SwiftUI
// The figures are internal: drawing them directly gives the rest pose without the avatars' appear animation.
@testable import HeroArt

/// Super Dad with a smiling baby, laid out like the home screen's family (child canvas at 0.62 of the dad's height),
/// a little closer together so the pair reads as one picture.
/// The website draws each figure on its own, at rest or cheering, in the same place: `showsHero`/`showsChild` hide the
/// other figure without moving anything, and `headroom` leaves space above for raised arms.
struct LaunchFamily: View {
    let heroHeight: CGFloat
    var showsHero = true
    var showsChild = true
    var heroCheers = false
    var childCheers = false
    var headroom: CGFloat = 0

    var body: some View {
        let childHeight = heroHeight * 0.62
        HStack(alignment: .bottom, spacing: -heroHeight * 0.24) {
            HeroFigure(style: .hero, pose: .rest, isCheering: heroCheers)
                .environment(\.avatarSkin, .mediumLight)
                .scaleEffect(heroHeight / HeroFigure.designSize.height)
                .frame(width: heroHeight * HeroAvatar.aspectRatio, height: heroHeight)
                .opacity(showsHero ? 1 : 0)
                .zIndex(1)
            ChildFigure(stage: .baby, gender: .boy, traits: .smile, pose: .rest, isCheering: childCheers)
                .environment(\.avatarSkin, .mediumLight)
                .scaleEffect(childHeight / ChildFigure.designSize.height)
                .frame(width: childHeight * ChildAvatar.aspectRatio, height: childHeight)
                .padding(
                    .bottom,
                    HeroAvatar.groundInset(forSize: heroHeight) - ChildAvatar.groundInset(forSize: childHeight)
                )
                .opacity(showsChild ? 1 : 0)
        }
        .padding(.top, headroom)
    }
}

/// Crops transparent margins so the launch screen centres on the figures themselves.
func trimmed(_ image: CGImage) -> CGImage? {
    opaqueBounds(of: image).flatMap { image.cropping(to: $0) }
}

/// The smallest rectangle holding every visible pixel, in the image's pixels (origin at the top left).
func opaqueBounds(of image: CGImage) -> CGRect? {
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
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

/// Renders the family in one colour scheme, trimmed to the figures.
@MainActor
func renderFamily(heroHeight: CGFloat, scale: CGFloat, scheme: ColorScheme) -> CGImage {
    let renderer = ImageRenderer(content: LaunchFamily(heroHeight: heroHeight).environment(\.colorScheme, scheme))
    renderer.scale = scale
    guard let image = renderer.cgImage.flatMap(trimmed) else { fatalError("Could not render the family") }
    return image
}

/// The family centred on a plain ground, for link previews.
func framed(_ figures: CGImage, width: Int, height: Int, ground: CGColor, contentHeight: Int) -> CGImage {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
              data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else { fatalError("Could not make the preview canvas") }
    context.setFillColor(ground)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let scale = CGFloat(contentHeight) / CGFloat(figures.height)
    let size = CGSize(width: CGFloat(figures.width) * scale, height: CGFloat(contentHeight))
    context.interpolationQuality = .high
    context.draw(figures, in: CGRect(origin: CGPoint(x: (CGFloat(width) - size.width) / 2,
                                                    y: (CGFloat(height) - size.height) / 2), size: size))
    guard let image = context.makeImage() else { fatalError("Could not draw the preview") }
    return image
}

func write(_ image: CGImage, to path: String) {
    guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(path)")
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
    } catch {
        fatalError("Could not write \(path): \(error)")
    }
    print("Wrote \(path) (\(image.width)×\(image.height))")
}

/// The website's family (ADR-0040): each figure at rest and cheering, as the app draws them when tapped. All eight
/// images come from one canvas; each figure is cropped to the box that holds both its poses, so swapping rest for cheer
/// moves nothing. Prints each figure's box as a share of the whole family, for `site.css`.
@MainActor
func writeWebFamily(scheme: ColorScheme, name: String) {
    let heroHeight: CGFloat = 340, scale: CGFloat = 2
    func render(_ family: LaunchFamily) -> CGImage {
        let renderer = ImageRenderer(content: family.environment(\.colorScheme, scheme))
        renderer.scale = scale
        guard let image = renderer.cgImage else { fatalError("Could not render the family") }
        return image
    }
    let headroom = heroHeight * 0.3
    /// One figure on the website, drawn at rest and cheering.
    struct Figure { let file: String; let rest: CGImage; let cheer: CGImage }
    let figures = [
        Figure(file: "dad",
               rest: render(LaunchFamily(heroHeight: heroHeight, showsChild: false, headroom: headroom)),
               cheer: render(LaunchFamily(heroHeight: heroHeight, showsChild: false, heroCheers: true,
                                          headroom: headroom))),
        Figure(file: "baby",
               rest: render(LaunchFamily(heroHeight: heroHeight, showsHero: false, headroom: headroom)),
               cheer: render(LaunchFamily(heroHeight: heroHeight, showsHero: false, childCheers: true,
                                          headroom: headroom)))
    ]
    let boxes = figures.map { figure -> CGRect in
        guard let rest = opaqueBounds(of: figure.rest), let cheer = opaqueBounds(of: figure.cheer) else {
            fatalError("Nothing drawn for \(figure.file)")
        }
        return rest.union(cheer)
    }
    let family = boxes.dropFirst().reduce(boxes[0]) { $0.union($1) }
    for (figure, box) in zip(figures, boxes) {
        for (pose, image) in [("rest", figure.rest), ("cheer", figure.cheer)] {
            guard let cropped = image.cropping(to: box) else { fatalError("Could not crop \(figure.file)") }
            write(cropped, to: "web/assets/family/\(figure.file)-\(pose)-\(name).png")
        }
        if name == "light" {
            func percent(_ value: CGFloat, of whole: CGFloat) -> String { String(format: "%.2f%%", value / whole * 100) }
            print(".family .\(figure.file) { left: \(percent(box.minX - family.minX, of: family.width)); "
                + "top: \(percent(box.minY - family.minY, of: family.height)); "
                + "width: \(percent(box.width, of: family.width)); }")
        }
    }
    if name == "light" {
        print(".family { aspect-ratio: \(Int(family.width)) / \(Int(family.height)); }")
    }
}

/// The launch screen (ADR-0025) and the website (ADR-0031, ADR-0040) show the same family, so one run writes both.
let launchImages = "App/Resources/Assets.xcassets/LaunchLogo.imageset"
/// One rendering pass per launch appearance: the asset name suffix and the colour scheme to draw in.
let appearances: [(name: String, scheme: ColorScheme)] = [("light", .light), ("dark", .dark)]
for entry in appearances {
    NSAppearance(named: entry.scheme == .dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
        MainActor.assumeIsolated {
            for scale in [2, 3] {
                let image = renderFamily(heroHeight: 340, scale: CGFloat(scale), scheme: entry.scheme)
                write(image, to: "\(launchImages)/LaunchLogo-\(entry.name)@\(scale)x.png")
            }
            writeWebFamily(scheme: entry.scheme, name: entry.name)
            if entry.scheme == .light {
                // 1200×630, the size link previews expect, on the light background (`DSColor.background`).
                let figures = renderFamily(heroHeight: 340, scale: 4, scheme: .light)
                let ground = CGColor(srgbRed: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF7 / 255, alpha: 1)
                write(framed(figures, width: 1200, height: 630, ground: ground, contentHeight: 560), to: "web/assets/og.png")
            }
        }
    }
}
