/// Who plays a score, and how: an accompaniment pattern, the tune's instrument, a bass line, a pad, maybe drums.
struct Band {
    var comping: Comping
    var lead: Lead
    var bass: BassLine
    /// The airy chord under every bar, an octave above the chord tones. Zero leaves it out.
    var padVelocity: Double
    var drums: Drums?
    /// How much reverb is mixed in, 0...1.
    var reverb: Float
}

/// One hit of a pattern: when in the bar, in beats, and which of the chord's four tones sound.
struct Step {
    let beat: Double
    let tones: [Int]

    init(_ beat: Double, _ tones: Int...) {
        self.beat = beat
        self.tones = tones
    }

    /// One chord tone per step, `stepLength` beats apart.
    static func arpeggio(_ tones: [Int], every stepLength: Double) -> [Step] {
        tones.enumerated().map { Step(Double($0.offset) * stepLength, $0.element) }
    }
}

/// The chords, played as a repeating pattern.
struct Comping {
    let instrument: Instrument
    let steps: [Step]
    /// Semitones above the chord tones.
    let octave: Int
    let velocity: Double
    /// Steps on a multiple of this many beats are played louder.
    let accentEvery: Double
    let pan: Float
}

struct Lead {
    let instrument: Instrument
    let velocity: Double
    let pan: Float
}

struct BassLine {
    let steps: [Step]
    /// Semitones above the chord tones (usually negative).
    let octave: Int
    let velocity: Double
}

/// Beats of the bar each drum plays on, in `driving` bars only. The timpani is tuned to the chord's root.
struct Drums {
    var kick: [Double] = []
    var snare: [Double] = []
    var hat: [Double] = []
    var timpani: [Double] = []
    var velocity: Double
}
