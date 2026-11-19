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

/// The instruments, drawn from sine partials so every note is exactly in tune.
enum Instrument {
    static func frequency(_ pitch: Int) -> Double {
        440 * pow(2, Double(pitch - 69) / 12)
    }

    /// A soft plucked string, like a ukulele: bright partials that fade faster than the low ones.
    static func pluck(_ pitch: Int, velocity: Double) -> [Float] {
        partials(pitch, seconds: 2.4) { harmonic, time in
            let attack = min(1, time / 0.004)
            return attack * velocity / pow(harmonic, 1.5) * exp(-time * (1.6 + 1.3 * harmonic))
        }
    }

    /// A warm bell for the tune, held for `length` seconds and then let ring out.
    static func bell(_ pitch: Int, length: Double, velocity: Double) -> [Float] {
        let weights: [Double: Double] = [1: 1, 2: 0.22, 3: 0.07, 4.1: 0.04]
        return partials(pitch, seconds: length + 1.6, harmonics: weights.keys.sorted()) { harmonic, time in
            let attack = min(1, time / 0.012)
            let release = time > length ? exp(-(time - length) * 3.5) : 1
            let vibrato = 1 + 0.0015 * sin(2 * .pi * 5 * time) * min(1, time / 0.6)
            return attack * release * velocity * (weights[harmonic] ?? 0) * exp(-time * 0.7) * vibrato
        }
    }

    /// A round, quiet bass note.
    static func bass(_ pitch: Int, velocity: Double) -> [Float] {
        partials(pitch, seconds: 1.8, harmonics: [1, 2]) { harmonic, time in
            let attack = min(1, time / 0.01)
            return attack * velocity * (harmonic == 1 ? 1 : 0.25) * exp(-time * 1.6)
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
