// usage: sheet <in.mp4> <out.jpg> — contact sheet of one frame every 2.5 s (0.5 s to 45 s), 6 columns, JPEG
import AVFoundation
import AppKit

let args = CommandLine.arguments
guard args.count > 2 else { fatalError("usage: sheet <in.mp4> <out.jpg>") }
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let gen = AVAssetImageGenerator(asset: asset)
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
let times = stride(from: 0.5, to: 45.0, by: 2.5).map { $0 }
let cols = 6
let cellWidth = 270
let cellHeight = 587
let rows = (times.count + cols - 1) / cols
let img = NSImage(size: NSSize(width: cols * cellWidth, height: rows * cellHeight))
img.lockFocus()
for (index, time) in times.enumerated() {
    if let frame = try? gen.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil) {
        let row = index / cols
        let col = index % cols
        NSImage(cgImage: frame, size: .zero).draw(in: NSRect(
            x: col * cellWidth, y: (rows - 1 - row) * cellHeight, width: cellWidth, height: cellHeight))
    }
}
img.unlockFocus()
guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
    fatalError("usage: sheet: cannot encode the JPEG")
}
try jpeg.write(to: URL(fileURLWithPath: args[2]))
