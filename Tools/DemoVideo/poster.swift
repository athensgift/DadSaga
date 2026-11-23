// usage: poster <in.mp4> <time s> <out.jpg> — one frame, 540 px wide, JPEG
import AVFoundation
import AppKit

let args = CommandLine.arguments
guard args.count > 3, let seconds = Double(args[2]) else {
    fatalError("usage: poster <in.mp4> <time s> <out.jpg>")
}
let gen = AVAssetImageGenerator(asset: AVURLAsset(url: URL(fileURLWithPath: args[1])))
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
let frame = try gen.copyCGImage(at: CMTime(seconds: seconds, preferredTimescale: 600), actualTime: nil)
let width = 540
let height = Int((Double(frame.height) * 540 / Double(frame.width) / 2).rounded()) * 2
guard let ctx = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("usage: poster: cannot create a bitmap context") }
ctx.interpolationQuality = .high
ctx.draw(frame, in: CGRect(x: 0, y: 0, width: width, height: height))
guard let scaled = ctx.makeImage(),
      let jpeg = NSBitmapImageRep(cgImage: scaled)
        .representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else {
    fatalError("usage: poster: cannot encode the JPEG")
}
try jpeg.write(to: URL(fileURLWithPath: args[3]))
print(width, height)
