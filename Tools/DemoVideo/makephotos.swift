// usage: makephotos <out dir> — five 1200x1500 JPEG "photos" (1-park.jpg … 5-bath.jpg) from web/assets/family/*.png
// Run from the repository root: it reads the figures from web/assets/family/ there.
import AppKit
import CoreGraphics

let family = FileManager.default.currentDirectoryPath + "/web/assets/family/"
guard CommandLine.arguments.count > 1 else { fatalError("usage: makephotos <out dir>") }
let outDir = CommandLine.arguments[1]

func figureImage(_ name: String) -> CGImage {
    guard let image = NSImage(contentsOfFile: family + name + ".png"),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("usage: makephotos: cannot read \(family + name).png")
    }
    return cgImage
}

struct RGB { let red: CGFloat; let green: CGFloat; let blue: CGFloat }
struct Fig { let name: String; let cenX: CGFloat; let height: CGFloat; let posY: CGFloat }
struct Photo { let file: String; let top: RGB; let bottom: RGB; let figs: [Fig] }

let width: CGFloat = 1200
let height: CGFloat = 1500
let photos = [
    Photo(file: "1-park", top: RGB(red: 0.55, green: 0.80, blue: 0.95), bottom: RGB(red: 0.62, green: 0.85, blue: 0.55),
          figs: [Fig(name: "dad-cheer-light", cenX: 0.40, height: 1050, posY: 120),
                 Fig(name: "baby-cheer-light", cenX: 0.72, height: 420, posY: 120)]),
    Photo(file: "2-nap", top: RGB(red: 0.36, green: 0.42, blue: 0.70), bottom: RGB(red: 0.70, green: 0.62, blue: 0.85),
          figs: [Fig(name: "baby-rest-light", cenX: 0.5, height: 760, posY: 300)]),
    Photo(file: "3-first-steps", top: RGB(red: 1.0, green: 0.82, blue: 0.55), bottom: RGB(red: 1.0, green: 0.62, blue: 0.50),
          figs: [Fig(name: "baby-cheer-light", cenX: 0.5, height: 820, posY: 240)]),
    Photo(file: "4-walk", top: RGB(red: 0.75, green: 0.90, blue: 0.80), bottom: RGB(red: 0.40, green: 0.70, blue: 0.60),
          figs: [Fig(name: "dad-rest-light", cenX: 0.45, height: 1050, posY: 120),
                 Fig(name: "baby-rest-light", cenX: 0.76, height: 400, posY: 120)]),
    Photo(file: "5-bath", top: RGB(red: 0.70, green: 0.88, blue: 1.0), bottom: RGB(red: 0.45, green: 0.70, blue: 0.95),
          figs: [Fig(name: "baby-cheer-light", cenX: 0.32, height: 520, posY: 200),
                 Fig(name: "baby-rest-light", cenX: 0.70, height: 520, posY: 200)])
]
let colorSpace = CGColorSpaceCreateDeviceRGB()
for photo in photos {
    guard let ctx = CGContext(
        data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fatalError("usage: makephotos: cannot create a bitmap context")
    }
    let bottom = CGColor(red: photo.bottom.red, green: photo.bottom.green, blue: photo.bottom.blue, alpha: 1)
    let top = CGColor(red: photo.top.red, green: photo.top.green, blue: photo.top.blue, alpha: 1)
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: [bottom, top] as CFArray, locations: [0, 1]) else {
        fatalError("usage: makephotos: cannot create the gradient")
    }
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [])
    // soft sun
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.25))
    ctx.fillEllipse(in: CGRect(x: width * 0.68, y: height * 0.72, width: 260, height: 260))
    // ground ellipse shadow
    for fig in photo.figs {
        let image = figureImage(fig.name)
        let figWidth = fig.height * CGFloat(image.width) / CGFloat(image.height)
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: width * fig.cenX - figWidth / 2, y: fig.posY, width: figWidth, height: fig.height))
    }
    guard let rendered = ctx.makeImage(),
          let jpeg = NSBitmapImageRep(cgImage: rendered)
            .representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
        fatalError("usage: makephotos: cannot encode the JPEG")
    }
    try jpeg.write(to: URL(fileURLWithPath: outDir + "/" + photo.file + ".jpg"))
}
