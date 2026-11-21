extension Score {
    /// A warm, wistful tune in A major at 96 beats a minute: a fingerpicked guitar and a flute.
    /// Intro, A (guitar and flute alone), B with bass, A, B, A alone again, B, and an ending that comes home to A.
    static let homeward = Score(
        id: "like-yesterday",
        beatsPerMinute: 96,
        beatsPerBar: 4,
        band: Band(
            comping: Comping(instrument: .guitar, steps: Step.arpeggio([0, 2, 1, 3, 0, 2, 1, 3], every: 0.5),
                             octave: 0, velocity: 0.17, accentEvery: 2, pan: -0.2),
            lead: Lead(instrument: .flute, velocity: 0.2, pan: 0.15),
            bass: BassLine(steps: [Step(0, 0), Step(2, 1)], octave: -12, velocity: 0.18),
            padVelocity: 0.006,
            reverb: 0.38
        ),
        bars: section(.light, [("A", ""), ("E", ""), ("F#m", ""), ("D", "")])
            + section(.light, homewardA)
            + section(.full, homewardB)
            + section(.full, homewardA)
            + section(.full, homewardB)
            + section(.light, homewardA)
            + section(.full, homewardB)
            + section(.full, [("D", "F#5/3 E5"), ("E", "E5/2 D5 B4")])
            + section(.light, [("A", "C#5/4"), ("A", "A4/4")])
    )

    private static let homewardA: [(chord: String, tune: String)] = [
        ("A", "C#5/1.5 B4/.5 A4 C#5"),
        ("E", "B4/3 -"),
        ("F#m", "A4/1.5 B4/.5 C#5 F#5"),
        ("D", "E5/3 -"),
        ("A", "C#5/1.5 B4/.5 A4 E5"),
        ("E", "D5/1.5 C#5/.5 B4/2"),
        ("D", "A4 B4 C#5 F#5"),
        ("E", "E5/4")
    ]

    private static let homewardB: [(chord: String, tune: String)] = [
        ("D", "F#5/1.5 E5/.5 D5 A5"),
        ("A", "E5/3 C#5"),
        ("E", "B4 C#5 D5 E5"),
        ("F#m", "C#5/3 -"),
        ("D", "D5/1.5 E5/.5 F#5 A5"),
        ("A", "A5/1.5 G#5/.5 E5/2"),
        ("Bm", "F#5 E5 D5 B4"),
        ("E", "B4/4")
    ]
}
