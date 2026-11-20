extension Score {
    /// A heroic march in D minor at 100 beats a minute: a plucked ostinato, a brass tune, timpani and drums.
    /// Intro, A, A with drums, B (brighter, in the major keys), A, and an ending that lands on D minor.
    static let adventure = Score(
        id: "great-adventure",
        beatsPerMinute: 100,
        beatsPerBar: 4,
        band: Band(
            comping: Comping(instrument: .pluck, steps: Step.arpeggio([0, 0, 1, 0, 2, 0, 1, 0], every: 0.5),
                             octave: 12, velocity: 0.13, accentEvery: 1.5, pan: -0.3),
            lead: Lead(instrument: .brass, velocity: 0.13, pan: 0.15),
            bass: BassLine(steps: [Step(0, 0), Step(1.5, 0), Step(3, 1)], octave: -12, velocity: 0.24),
            padVelocity: 0.011,
            drums: Drums(kick: [0, 1.5], snare: [1, 3], timpani: [0, 2], velocity: 0.34),
            reverb: 0.4
        ),
        bars: section(.light, [("Dm", ""), ("Bb", ""), ("F", ""), ("C", "")])
            + section(.full, adventureA(ending: ("A", "A4/3 -")))
            + section(.driving, adventureA(ending: ("Dm", "D5/3 -")))
            + section(.driving, adventureB)
            + section(.driving, adventureA(ending: ("Dm", "D5/3 -")))
            + section(.driving, [("Bb", "D5/4"), ("C", "E5/4")])
            + section(.full, [("A", "C#5/2 E5/2")])
            + section(.light, [("Dm", "D5/4")])
    )

    private static func adventureA(ending: (chord: String, tune: String)) -> [(chord: String, tune: String)] {
        [
            ("Dm", "D4/.75 D4/.25 A4/2 G4/.5 F4/.5"),
            ("Bb", "F4/.5 G4/.5 Bb4 A4 F4"),
            ("F", "C5/2 A4 F4"),
            ("C", "G4/3 -"),
            ("Dm", "D4/.75 D4/.25 A4/2 Bb4/.5 C5/.5"),
            ("Bb", "D5/2 C5 Bb4"),
            ("Gm", "Bb4 A4 G4 Bb4"),
            ending
        ]
    }

    private static let adventureB: [(chord: String, tune: String)] = [
        ("Bb", "F5/2 D5 Bb4"),
        ("F", "C5/2 A4 C5"),
        ("C", "E5/.75 E5/.25 G5 E5 C5"),
        ("Dm", "D5/2 A4/2"),
        ("Bb", "Bb4/.5 C5/.5 D5 F5 D5"),
        ("F", "C5 A4 F5/2"),
        ("Gm", "G5/1.5 F5/.5 E5 D5"),
        ("A", "E5/2 C#5/2")
    ]
}
