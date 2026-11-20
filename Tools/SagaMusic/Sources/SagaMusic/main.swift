import Foundation

/// Plays a score into a stereo buffer, bar by bar. Timing and loudness vary a little, the same way on every run.
struct Performance {
    private let score: Score
    private var random = SeededRandom(seed: 2_026)
    private var drumKit = DrumKit()
    private(set) var mix: Stereo

    init(_ score: Score) {
        self.score = score
        mix = Stereo(seconds: Double(score.bars.count) * score.bar + 4)
        for (number, bar) in score.bars.enumerated() {
            play(bar, at: Double(number) * score.bar, isLast: number == score.bars.count - 1)
        }
    }

    private mutating func play(_ bar: Bar, at start: Double, isLast: Bool) {
        let band = score.band
        let tones = bar.chord.tones
        let comping = band.comping
        // The last bar plays only the first half of the pattern and lets it ring.
        let steps = isLast ? comping.steps.filter { $0.beat < score.beatsPerBar / 2 } : comping.steps
        for step in steps {
            let accent = step.beat.truncatingRemainder(dividingBy: comping.accentEvery) == 0 ? 1.0 : 0.78
            let time = start + step.beat * score.beat + random.next(in: -0.008...0.008)
            let velocity = comping.velocity * accent * random.next(in: 0.9...1.1)
            for tone in step.tones {
                mix.add(comping.instrument.play(tones[tone] + comping.octave, length: score.beat, velocity: velocity),
                        at: max(0, time), pan: comping.pan)
            }
        }
        if band.padVelocity > 0 {
            mix.add(Instrument.pad(tones.map { $0 + 12 }, seconds: isLast ? score.bar * 1.5 : score.bar,
                                   velocity: band.padVelocity),
                    at: start, pan: 0)
        }
        for note in bar.tune {
            let time = start + note.beat * score.beat + random.next(in: -0.006...0.006)
            mix.add(band.lead.instrument.play(note.pitch, length: note.length * score.beat * 0.92,
                                              velocity: band.lead.velocity * random.next(in: 0.92...1.05)),
                    at: max(0, time), pan: band.lead.pan)
        }
        if bar.texture >= .full {
            for step in band.bass.steps {
                for tone in step.tones {
                    mix.add(Instrument.bass.play(tones[tone] + band.bass.octave, length: score.beat,
                                                 velocity: band.bass.velocity),
                            at: start + step.beat * score.beat, pan: 0)
                }
            }
        }
        if bar.texture == .driving, let drums = band.drums {
            playDrums(drums, root: tones[0], at: start)
        }
    }

    private mutating func playDrums(_ drums: Drums, root: Int, at start: Double) {
        for beat in drums.kick {
            mix.add(drumKit.kick(velocity: drums.velocity * random.next(in: 0.9...1.05)),
                    at: start + beat * score.beat, pan: 0)
        }
        for beat in drums.snare {
            mix.add(drumKit.snare(velocity: 0.45 * drums.velocity * random.next(in: 0.85...1.05)),
                    at: start + beat * score.beat, pan: 0.1)
        }
        for beat in drums.hat {
            let accent = beat.truncatingRemainder(dividingBy: 1) == 0 ? 1.0 : 0.7
            mix.add(drumKit.hat(velocity: 0.3 * drums.velocity * accent * random.next(in: 0.8...1.1)),
                    at: start + beat * score.beat, pan: 0.3)
        }
        for beat in drums.timpani {
            mix.add(drumKit.timpani(root - 12, velocity: 0.8 * drums.velocity * random.next(in: 0.9...1.05)),
                    at: start + beat * score.beat, pan: -0.1)
        }
    }
}

/// A small linear congruential generator, so the humanising is the same on every run.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let unit = Double(state >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}

/// Reverb, a soft limiter, a peak of −1 dBFS and a fade over the last four seconds, then 16-bit stereo samples.
func finish(_ mix: Stereo, reverb wet: Float) -> [Int16] {
    let left = Reverb.apply(to: mix.left, spread: 0, wet: wet)
    let right = Reverb.apply(to: mix.right, spread: 23, wet: wet)
    let fadeStart = mix.count - Int(4 * Stereo.sampleRate)
    var shaped: [Float] = []
    shaped.reserveCapacity(mix.count * 2)
    for index in 0..<mix.count {
        let fade = index > fadeStart ? Float(mix.count - index) / Float(mix.count - fadeStart) : 1
        shaped.append(tanh(left[index] * 1.2) * fade)
        shaped.append(tanh(right[index] * 1.2) * fade)
    }
    let peak = shaped.map(abs).max() ?? 1
    let gain = 0.89 / max(peak, 0.0001)
    return shaped.map { Int16(($0 * gain * 32_767).rounded()) }
}

/// Root-mean-square level in dB below full scale, to keep the pieces about as loud as each other.
func loudness(_ samples: [Int16]) -> Double {
    let power = samples.reduce(0.0) { $0 + pow(Double($1) / 32_768, 2) } / Double(samples.count)
    return 10 * log10(power)
}

func wav(_ samples: [Int16]) -> Data {
    var data = Data()
    func append<Value>(_ value: Value) {
        withUnsafeBytes(of: value) { data.append(contentsOf: $0) }
    }
    let bytes = UInt32(samples.count * 2)
    data.append(contentsOf: Array("RIFF".utf8))
    append(UInt32(36 + bytes).littleEndian)
    data.append(contentsOf: Array("WAVEfmt ".utf8))
    append(UInt32(16).littleEndian)
    append(UInt16(1).littleEndian)
    append(UInt16(2).littleEndian)
    append(UInt32(44_100).littleEndian)
    append(UInt32(44_100 * 4).littleEndian)
    append(UInt16(4).littleEndian)
    append(UInt16(16).littleEndian)
    data.append(contentsOf: Array("data".utf8))
    append(bytes.littleEndian)
    samples.forEach { append($0.littleEndian) }
    return data
}

let arguments = CommandLine.arguments
guard (2...3).contains(arguments.count) else {
    print("Usage: SagaMusic <output folder> [score id]")
    exit(1)
}
let folder = URL(fileURLWithPath: arguments[1], isDirectory: true)
let scores = arguments.count == 3 ? Score.all.filter { $0.id == arguments[2] } : Score.all
guard !scores.isEmpty else {
    print("No score \(arguments[2]). Scores: \(Score.all.map(\.id).joined(separator: ", "))")
    exit(1)
}
for score in scores {
    let performance = Performance(score)
    let samples = finish(performance.mix, reverb: score.band.reverb)
    let url = folder.appendingPathComponent("\(score.id).wav")
    try wav(samples).write(to: url)
    let seconds = Double(performance.mix.count) / Stereo.sampleRate
    print("Wrote \(url.path): \(seconds) s, \(String(format: "%.1f", loudness(samples))) dBFS RMS")
}
