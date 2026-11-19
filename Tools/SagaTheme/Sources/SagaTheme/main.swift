import Foundation

/// Plays the score into a stereo buffer: plucked chords, an airy pad, the tune on a bell, and bass in the fuller parts.
/// Timing and loudness vary a little, the same way on every run.
struct Performance {
    private var random = SeededRandom(seed: 2_026)
    private(set) var mix: Stereo

    private static let beat = 60 / Score.beatsPerMinute
    private static let bar = beat * Score.beatsPerBar
    /// The arpeggio, as indexes into the chord's four tones, one per eighth note.
    private static let arpeggio = [0, 1, 2, 3, 2, 1, 2, 3]

    init() {
        mix = Stereo(seconds: Double(Score.bars.count) * Self.bar + 4)
        for (number, bar) in Score.bars.enumerated() {
            play(bar, at: Double(number) * Self.bar, isLast: number == Score.bars.count - 1)
        }
    }

    private mutating func play(_ bar: Score.Bar, at start: Double, isLast: Bool) {
        let tones = bar.chord.tones
        let eighths = isLast ? Array(Self.arpeggio.prefix(4)) : Self.arpeggio
        for (step, tone) in eighths.enumerated() {
            let accent = step % 4 == 0 ? 1.0 : 0.78
            let time = start + Double(step) * Self.beat / 2 + random.next(in: -0.008...0.008)
            mix.add(Instrument.pluck(tones[tone] + 12, velocity: 0.16 * accent * random.next(in: 0.9...1.1)),
                    at: max(0, time), pan: -0.25)
        }
        mix.add(Instrument.pad(tones.map { $0 + 12 }, seconds: isLast ? Self.bar * 1.5 : Self.bar, velocity: 0.007),
                at: start, pan: 0)
        for note in bar.tune {
            let time = start + note.beat * Self.beat + random.next(in: -0.006...0.006)
            mix.add(Instrument.bell(note.pitch, length: note.length * Self.beat * 0.92,
                                    velocity: 0.2 * random.next(in: 0.92...1.05)),
                    at: max(0, time), pan: 0.2)
        }
        if bar.hasBass {
            for beat in [0.0, 2.0] {
                mix.add(Instrument.bass(tones[0] - 12, velocity: 0.22), at: start + beat * Self.beat, pan: 0)
            }
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

/// Reverb, a soft limiter, a peak of −1 dBFS and a fade over the last four seconds, then 16-bit stereo WAV.
func finish(_ mix: Stereo) -> [Int16] {
    let left = Reverb.apply(to: mix.left, spread: 0, wet: 0.35)
    let right = Reverb.apply(to: mix.right, spread: 23, wet: 0.35)
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
guard arguments.count == 2 else {
    print("Usage: SagaTheme <output.wav>")
    exit(1)
}
let performance = Performance()
try wav(finish(performance.mix)).write(to: URL(fileURLWithPath: arguments[1]))
print("Wrote \(arguments[1]): \(Double(performance.mix.count) / Stereo.sampleRate) s")
