/// The theme's score: a gentle tune in D major at 80 beats a minute, four beats a bar.
///
/// Intro (plucked chords alone), A (the tune), B (higher, with bass), A again, and an ending that settles on D.
enum Score {
    static let beatsPerMinute = 80.0
    static let beatsPerBar = 4.0

    /// A note of the tune: when it starts in its bar, how long it lasts, both in beats, and its MIDI pitch.
    struct Note {
        let beat: Double
        let length: Double
        let pitch: Int

        init(_ beat: Double, _ length: Double, _ pitch: Int) {
            self.beat = beat
            self.length = length
            self.pitch = pitch
        }
    }

    struct Bar {
        let chord: Chord
        let tune: [Note]
        let hasBass: Bool
    }

    enum Chord {
        case dMajor, aMajor, bMinor, gMajor, eMinor

        /// Four chord tones, low to high, around middle C.
        var tones: [Int] {
            switch self {
            case .dMajor: [50, 57, 62, 66]
            case .aMajor: [45, 52, 57, 61]
            case .bMinor: [47, 54, 59, 62]
            case .gMajor: [43, 50, 55, 59]
            case .eMinor: [40, 47, 52, 55]
            }
        }
    }

    static let bars: [Bar] = intro + tuneA(ending: tuneAEnd) + tuneB + tuneA(ending: tuneAEnd) + ending

    private static let intro: [Bar] = [Chord.dMajor, .aMajor, .bMinor, .gMajor].map {
        Bar(chord: $0, tune: [], hasBass: false)
    }

    private static let tuneAEnd = [Note(0, 3, 76)]

    private static func tuneA(ending: [Note]) -> [Bar] {
        [
            Bar(chord: .dMajor, tune: [Note(0, 1.5, 78), Note(1.5, 0.5, 76), Note(2, 1, 74), Note(3, 1, 76)], hasBass: false),
            Bar(chord: .aMajor, tune: [Note(0, 2, 73), Note(2, 1, 76), Note(3, 1, 73)], hasBass: false),
            Bar(chord: .bMinor, tune: [Note(0, 1.5, 74), Note(1.5, 0.5, 73), Note(2, 2, 71)], hasBass: false),
            Bar(chord: .gMajor, tune: [Note(0, 1, 71), Note(1, 1, 74), Note(2, 2, 79)], hasBass: false),
            Bar(chord: .dMajor, tune: [Note(0, 1.5, 78), Note(1.5, 0.5, 79), Note(2, 1, 81), Note(3, 1, 78)], hasBass: true),
            Bar(chord: .aMajor, tune: [Note(0, 2, 76), Note(2, 1, 73), Note(3, 1, 76)], hasBass: true),
            Bar(chord: .gMajor, tune: [Note(0, 1, 74), Note(1, 1, 71), Note(2, 1, 74), Note(3, 1, 79)], hasBass: true),
            Bar(chord: .aMajor, tune: ending, hasBass: true)
        ]
    }

    private static let tuneB: [Bar] = [
        Bar(chord: .gMajor, tune: [Note(0, 2, 83), Note(2, 1, 81), Note(3, 1, 79)], hasBass: true),
        Bar(chord: .dMajor, tune: [Note(0, 2, 81), Note(2, 2, 78)], hasBass: true),
        Bar(chord: .aMajor, tune: [Note(0, 1, 76), Note(1, 1, 78), Note(2, 1, 81), Note(3, 1, 76)], hasBass: true),
        Bar(chord: .bMinor, tune: [Note(0, 3, 78)], hasBass: true),
        Bar(chord: .gMajor, tune: [Note(0, 1, 79), Note(1, 1, 81), Note(2, 2, 83)], hasBass: true),
        Bar(chord: .dMajor, tune: [Note(0, 2, 86), Note(2, 2, 81)], hasBass: true),
        Bar(chord: .eMinor, tune: [Note(0, 1, 79), Note(1, 1, 78), Note(2, 2, 76)], hasBass: true),
        Bar(chord: .aMajor, tune: [Note(0, 2, 73), Note(2, 1, 76), Note(3, 1, 73)], hasBass: true)
    ]

    private static let ending: [Bar] = [
        Bar(chord: .gMajor, tune: [Note(0, 2, 79), Note(2, 2, 78)], hasBass: true),
        Bar(chord: .dMajor, tune: [Note(0, 4, 78)], hasBass: true),
        Bar(chord: .aMajor, tune: [Note(0, 4, 76)], hasBass: false),
        Bar(chord: .dMajor, tune: [Note(0, 4, 74)], hasBass: false)
    ]
}
