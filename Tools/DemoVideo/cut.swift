// usage: cut <in.mp4> <out.mp4> <bitrate bps> <start-end> [<start-end> ...]
// Joins the given ranges of a simctl recording, scales to 540 px wide, 30 fps, H.264, no audio.
import AVFoundation

let args = CommandLine.arguments
let usage = "usage: cut <in.mp4> <out.mp4> <bitrate bps> <start-end> [<start-end> ...]"
guard args.count > 4, let bitrate = Int(args[3]) else { fatalError(usage) }
let src = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let outURL = URL(fileURLWithPath: args[2])
try? FileManager.default.removeItem(at: outURL)
let ranges = args.dropFirst(4).map { range -> (start: Double, end: Double) in
    let parts = range.split(separator: "-").compactMap { Double($0) }
    guard parts.count == 2 else { fatalError(usage) }
    return (parts[0], parts[1])
}
let sem = DispatchSemaphore(value: 0)
Task {
    guard let track = try await src.loadTracks(withMediaType: .video).first else { fatalError(usage) }
    let natural = try await track.load(.naturalSize)
    let comp = AVMutableComposition()
    guard let compTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
        fatalError("cut: cannot add a video track")
    }
    var cursor = CMTime.zero
    for (start, end) in ranges {
        let range = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600), end: CMTime(seconds: end, preferredTimescale: 600))
        try compTrack.insertTimeRange(range, of: track, at: cursor)
        cursor = CMTimeAdd(cursor, range.duration)
    }
    let width = 540.0
    let scale = width / natural.width
    let height = (natural.height * scale / 2).rounded() * 2
    let videoComp = AVMutableVideoComposition()
    videoComp.renderSize = CGSize(width: width, height: height)
    videoComp.frameDuration = CMTime(value: 1, timescale: 30)
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: cursor)
    let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: compTrack)
    layer.setTransform(CGAffineTransform(scaleX: scale, y: scale), at: .zero)
    instruction.layerInstructions = [layer]
    videoComp.instructions = [instruction]
    let reader = try AVAssetReader(asset: comp)
    let out = AVAssetReaderVideoCompositionOutput(
        videoTracks: [compTrack],
        videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    out.videoComposition = videoComp
    reader.add(out)
    let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoMaxKeyFrameIntervalKey: 60,
            AVVideoExpectedSourceFrameRateKey: 30
        ]
    ])
    input.expectsMediaDataInRealTime = false
    writer.add(input)
    writer.shouldOptimizeForNetworkUse = true
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
    reader.startReading()
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    // The recording only has frames when the screen changes: repeat the latest frame at a constant 30 fps.
    let total = Int((cursor.seconds * 30).rounded(.down))
    var tick = 0
    var last: CVPixelBuffer?
    func emit(upTo time: Double, _ buffer: CVPixelBuffer) {
        while tick < total && Double(tick) / 30 < time {
            while !input.isReadyForMoreMediaData { usleep(2000) }
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(tick), timescale: 30))
            tick += 1
        }
    }
    while let sample = out.copyNextSampleBuffer() {
        guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
        let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds
        emit(upTo: time, last ?? buffer)
        last = buffer
    }
    if let last { emit(upTo: cursor.seconds + 1, last) }
    input.markAsFinished()
    await writer.finishWriting()
    print("status", writer.status.rawValue, writer.error as Any, "duration", cursor.seconds, "size", width, height)
    sem.signal()
}
sem.wait()
