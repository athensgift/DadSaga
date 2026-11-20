/// A piece for the saga film: its tempo and metre, the band that plays it and its bars.
struct Score {
    /// The file name the piece is bundled under, without its extension.
    let id: String
    let beatsPerMinute: Double
    let beatsPerBar: Double
    let band: Band
    let bars: [Bar]

    init(id: String, beatsPerMinute: Double, beatsPerBar: Double, band: Band, bars: [Bar]) {
        for (number, bar) in bars.enumerated() {
            let length = bar.tune.map { $0.beat + $0.length }.max() ?? 0
            precondition(length <= beatsPerBar, "\(id): bar \(number + 1) holds \(length) beats")
        }
        self.id = id
        self.beatsPerMinute = beatsPerMinute
        self.beatsPerBar = beatsPerBar
        self.band = band
        self.bars = bars
    }

    var beat: Double { 60 / beatsPerMinute }
    var bar: Double { beat * beatsPerBar }

    /// Every piece, in the order `soundtracks.json` lists them.
    static let all: [Score] = [sagaTheme, party, lullaby, adventure, homeward]
}

/// How much of the band plays in a bar: the accompaniment, pad and tune always; bass from `full`; drums in `driving`.
enum Texture: Int, Comparable {
    case light, full, driving

    static func < (lhs: Texture, rhs: Texture) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct Bar {
    let chord: Chord
    let tune: [Note]
    let texture: Texture

    /// - Parameters:
    ///   - chord: a chord name such as `"D"`, `"Bm"` or `"F#m"`.
    ///   - tune: the tune's notes in order from the bar's first beat, such as `"F#5/1.5 E5/.5 D5 -/2"`: a pitch
    ///     (or `-` for a rest) and its length in beats after the slash, one beat when left out.
    init(_ chord: String, _ tune: String = "", _ texture: Texture) {
        self.chord = Chord(chord)
        self.tune = Note.parse(tune)
        self.texture = texture
    }
}

/// Builds bars of one texture from pairs of chord and tune.
func section(_ texture: Texture, _ pairs: [(chord: String, tune: String)]) -> [Bar] {
    pairs.map { Bar($0.chord, $0.tune, texture) }
}

/// A note of the tune: when it starts in its bar, how long it lasts, both in beats, and its MIDI pitch.
struct Note {
    let beat: Double
    let length: Double
    let pitch: Int

    static func parse(_ text: String) -> [Note] {
        var beat = 0.0
        var notes: [Note] = []
        for token in text.split(separator: " ") {
            let parts = token.split(separator: "/")
            guard let length = parts.count > 1 ? Double(parts[1]) : 1 else {
                preconditionFailure("Unreadable length in \(token)")
            }
            if parts[0] != "-" {
                notes.append(Note(beat: beat, length: length, pitch: Pitch.midi(String(parts[0]))))
            }
            beat += length
        }
        return notes
    }
}

/// Note names to MIDI numbers: `C4` is middle C, 60.
enum Pitch {
    static func midi(_ name: String) -> Int {
        guard let octave = Int(name.drop { !$0.isNumber && $0 != "-" }) else {
            preconditionFailure("No octave in \(name)")
        }
        return (octave + 1) * 12 + pitchClass(String(name.prefix { !$0.isNumber && $0 != "-" }))
    }

    /// `"C"` is 0, `"F#"` is 6, `"Bb"` is 10.
    static func pitchClass(_ name: String) -> Int {
        let letters: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard let letter = name.first, let natural = letters[letter] else {
            preconditionFailure("Unknown note \(name)")
        }
        let accidental = name.dropFirst().reduce(0) { sum, sign in sum + (sign == "#" ? 1 : sign == "b" ? -1 : 0) }
        return (natural + accidental + 12) % 12
    }
}

/// A major or minor chord, voiced as root, fifth, octave and the third above it, with the root from E2 to D#3.
struct Chord {
    /// Four chord tones, low to high.
    let tones: [Int]

    init(_ name: String) {
        let isMinor = name.hasSuffix("m")
        let rootClass = Pitch.pitchClass(String(isMinor ? name.dropLast() : name[...]))
        let root = 36 + rootClass < 40 ? 48 + rootClass : 36 + rootClass
        tones = [root, root + 7, root + 12, root + (isMinor ? 15 : 16)]
    }
}
