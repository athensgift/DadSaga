import Foundation

/// A stereo buffer the instruments play into, at 44.1 kHz.
struct Stereo {
    static let sampleRate = 44_100.0
    var left: [Float]
    var right: [Float]

    init(seconds: Double) {
        let count = Int(seconds * Self.sampleRate)
        left = Array(repeating: 0, count: count)
        right = Array(repeating: 0, count: count)
    }

    var count: Int { left.count }

    /// Adds a mono voice from `start` seconds, panned from −1 (left) to 1 (right).
    mutating func add(_ voice: [Float], at start: Double, pan: Float) {
        let first = Int(start * Self.sampleRate)
        let leftGain = sqrt((1 - pan) / 2)
        let rightGain = sqrt((1 + pan) / 2)
        for index in voice.indices where first + index < count && first + index >= 0 {
            left[first + index] += voice[index] * leftGain
            right[first + index] += voice[index] * rightGain
        }
    }
}

/// The pitched instruments, drawn from sine partials so every note is exactly in tune.
enum Instrument {
    /// A soft plucked string, like a ukulele: bright partials that fade faster than the low ones.
    case pluck
    /// A darker, longer-ringing nylon string for fingerpicking.
    case guitar
    /// A warm bell, held and then let ring out.
    case bell
    /// Tines of a music box: a few slightly out-of-tune partials that ring and fade.
    case musicBox
    /// A wooden bar: a short knock with its tuned fourth partial.
    case marimba
    /// A soft brass section: partials that open up as the note starts, held, with a little vibrato.
    case brass
    /// A breathy, almost pure tone with a late vibrato.
    case flute
    /// A round, quiet bass note.
    case bass

    static func frequency(_ pitch: Int) -> Double {
        440 * pow(2, Double(pitch - 69) / 12)
    }

    /// - Parameter length: how long the note is held, in seconds; struck and plucked instruments ignore it.
    func play(_ pitch: Int, length: Double, velocity: Double) -> [Float] {
        switch self {
        case .pluck:
            Self.partials(pitch, seconds: 2.4) { harmonic, time in
                let attack = min(1, time / 0.004)
                return attack * velocity / pow(harmonic, 1.5) * exp(-time * (1.6 + 1.3 * harmonic))
            }
        case .guitar:
            Self.partials(pitch, seconds: 3) { harmonic, time in
                let attack = min(1, time / 0.006)
                return attack * velocity / pow(harmonic, 1.8) * exp(-time * (0.9 + 0.9 * harmonic))
            }
        case .bell:
            Self.held(pitch, length: length, velocity: velocity, Sustained(
                weights: [1: 1, 2: 0.22, 3: 0.07, 4.1: 0.04], attackTime: 0.012, decay: 0.7, vibratoDepth: 0.0015
            ))
        case .musicBox:
            Self.struck(pitch, seconds: 2.6, velocity: velocity, weights: [1: 1, 2.76: 0.15, 5.4: 0.04], decay: 1.1,
                        attackTime: 0.006)
        case .marimba:
            Self.struck(pitch, seconds: 1.4, velocity: velocity, weights: [1: 1, 3.93: 0.25, 9.2: 0.05], decay: 3.5)
        case .brass:
            Self.brass(pitch, length: length, velocity: velocity)
        case .flute:
            Self.held(pitch, length: length, velocity: velocity, Sustained(
                weights: [1: 1, 2: 0.28, 3: 0.08], attackTime: 0.06, decay: 0.15, vibratoDepth: 0.004
            ))
        case .bass:
            Self.partials(pitch, seconds: 1.8, harmonics: [1, 2]) { harmonic, time in
                let attack = min(1, time / 0.01)
                return attack * velocity * (harmonic == 1 ? 1 : 0.25) * exp(-time * 1.6)
            }
        }
    }

    /// A slow, airy chord under everything: three gently detuned voices per tone.
    static func pad(_ pitches: [Int], seconds: Double, velocity: Double) -> [Float] {
        let total = seconds + 1.5
        var voice = [Float](repeating: 0, count: Int(total * Stereo.sampleRate))
        for pitch in pitches {
            for detune in [0.9975, 1, 1.0025] {
                let step = 2 * .pi * frequency(pitch) * detune / Stereo.sampleRate
                for index in voice.indices {
                    let time = Double(index) / Stereo.sampleRate
                    let swell = min(1, time / 0.9) * (time > seconds ? exp(-(time - seconds) * 2.5) : 1)
                    voice[index] += Float(velocity * swell * sin(step * Double(index)))
                }
            }
        }
        return voice
    }

    /// A note held for `length` seconds and then released, with a vibrato that grows in over its first 0.6 s.
    private static func held(_ pitch: Int, length: Double, velocity: Double, _ sound: Sustained) -> [Float] {
        partials(pitch, seconds: length + 1.6, harmonics: sound.weights.keys.sorted()) { harmonic, time in
            let attack = min(1, time / sound.attackTime)
            let release = time > length ? exp(-(time - length) * 3.5) : 1
            let vibrato = 1 + sound.vibratoDepth * sin(2 * .pi * 5 * time) * min(1, time / 0.6)
            return attack * release * velocity * (sound.weights[harmonic] ?? 0) * exp(-time * sound.decay) * vibrato
        }
    }

    /// The sound of a held instrument: its partials' weights, how fast it starts and fades, and its vibrato.
    private struct Sustained {
        let weights: [Double: Double]
        let attackTime: Double
        let decay: Double
        let vibratoDepth: Double
    }

    /// A struck note whose higher partials die away faster.
    private static func struck(
        _ pitch: Int,
        seconds: Double,
        velocity: Double,
        weights: [Double: Double],
        decay: Double,
        attackTime: Double = 0.002
    ) -> [Float] {
        partials(pitch, seconds: seconds, harmonics: weights.keys.sorted()) { harmonic, time in
            let attack = min(1, time / attackTime)
            return attack * velocity * (weights[harmonic] ?? 0) * exp(-time * decay * (0.6 + 0.4 * harmonic))
        }
    }

    private static func brass(_ pitch: Int, length: Double, velocity: Double) -> [Float] {
        partials(pitch, seconds: length + 0.8, harmonics: (1...10).map(Double.init)) { harmonic, time in
            let attack = min(1, time / 0.05)
            // The higher partials come in later, so each note opens up from soft to bright.
            let brightness = min(1, time / (0.03 * harmonic))
            let release = time > length ? exp(-(time - length) * 7) : 1
            let vibrato = 1 + 0.002 * sin(2 * .pi * 5.5 * time) * min(1, time / 0.4)
            return attack * brightness * release * velocity / harmonic * vibrato
        }
    }

    private static func partials(
        _ pitch: Int,
        seconds: Double,
        harmonics: [Double] = (1...8).map(Double.init),
        amplitude: (Double, Double) -> Double
    ) -> [Float] {
        var voice = [Float](repeating: 0, count: Int(seconds * Stereo.sampleRate))
        let base = frequency(pitch)
        for harmonic in harmonics where base * harmonic < Stereo.sampleRate / 2 {
            let step = 2 * .pi * base * harmonic / Stereo.sampleRate
            for index in voice.indices {
                let time = Double(index) / Stereo.sampleRate
                voice[index] += Float(amplitude(harmonic, time) * sin(step * Double(index)))
            }
        }
        return voice
    }
}

/// The drums. Noise comes from its own seeded generator, so a score with drums renders the same on every run.
struct DrumKit {
    private var noise = SeededRandom(seed: 7)

    /// A soft kick: a sine that drops from 110 to 45 Hz.
    func kick(velocity: Double) -> [Float] {
        var phase = 0.0
        return (0..<Int(0.35 * Stereo.sampleRate)).map { index in
            let time = Double(index) / Stereo.sampleRate
            phase += 2 * .pi * (45 + 65 * exp(-time * 30)) / Stereo.sampleRate
            return Float(velocity * min(1, time / 0.002) * exp(-time * 9) * sin(phase))
        }
    }

    /// A brushed snare: a burst of noise over a short 190 Hz tone.
    mutating func snare(velocity: Double) -> [Float] {
        (0..<Int(0.25 * Stereo.sampleRate)).map { index in
            let time = Double(index) / Stereo.sampleRate
            let rattle = noise.next(in: -1...1) * exp(-time * 18)
            let body = 0.4 * sin(2 * .pi * 190 * time) * exp(-time * 20)
            return Float(velocity * (rattle + body))
        }
    }

    /// A closed hi-hat: noise with its low end taken off, gone in a few tens of milliseconds.
    mutating func hat(velocity: Double) -> [Float] {
        var previous = 0.0
        return (0..<Int(0.08 * Stereo.sampleRate)).map { index in
            let time = Double(index) / Stereo.sampleRate
            let sample = noise.next(in: -1...1)
            defer { previous = sample }
            return Float(velocity * (sample - previous) * 0.5 * exp(-time * 60))
        }
    }

    /// A timpani: a low drum tuned to `pitch`, settling onto it as it rings.
    func timpani(_ pitch: Int, velocity: Double) -> [Float] {
        let base = Instrument.frequency(pitch)
        var phase = 0.0
        return (0..<Int(1.4 * Stereo.sampleRate)).map { index in
            let time = Double(index) / Stereo.sampleRate
            phase += 2 * .pi * base * (1 + 0.04 * exp(-time * 12)) / Stereo.sampleRate
            let tone = sin(phase) + 0.3 * sin(phase * 1.5) * exp(-time * 6)
            return Float(velocity * min(1, time / 0.003) * exp(-time * 3) * tone)
        }
    }
}

/// A small Schroeder reverb: four damped combs and two all-passes per channel, the right a little longer.
enum Reverb {
    static func apply(to signal: [Float], spread: Int, wet: Float) -> [Float] {
        let combs = [1557, 1617, 1491, 1422].map { $0 + spread }
        var output = [Float](repeating: 0, count: signal.count)
        for length in combs {
            var buffer = [Float](repeating: 0, count: length)
            var position = 0
            var filtered: Float = 0
            for index in signal.indices {
                let delayed = buffer[position]
                filtered = delayed * 0.75 + filtered * 0.25
                buffer[position] = signal[index] + filtered * 0.8
                output[index] += delayed / Float(combs.count)
                position = (position + 1) % length
            }
        }
        for length in [556 + spread, 441 + spread] {
            var buffer = [Float](repeating: 0, count: length)
            var position = 0
            for index in output.indices {
                let delayed = buffer[position]
                let input = output[index]
                buffer[position] = input + delayed * 0.5
                output[index] = delayed - input * 0.5
                position = (position + 1) % length
            }
        }
        return zip(signal, output).map { $0 + $1 * wet }
    }
}
