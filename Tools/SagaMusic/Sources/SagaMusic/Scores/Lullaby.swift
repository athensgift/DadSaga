extension Score {
    /// A lullaby in G major, three beats a bar at 72 a minute: a music box over a fingerpicked guitar and a soft pad.
    /// Intro, A (box and guitar alone), B, A and B with a low bass, and an ending that slows onto G.
    static let lullaby = Score(
        id: "music-box-lullaby",
        beatsPerMinute: 72,
        beatsPerBar: 3,
        band: Band(
            comping: Comping(instrument: .guitar, steps: Step.arpeggio([0, 1, 2, 3, 2, 1], every: 0.5),
                             octave: 12, velocity: 0.13, accentEvery: 3, pan: -0.25),
            lead: Lead(instrument: .musicBox, velocity: 0.26, pan: 0.2),
            bass: BassLine(steps: [Step(0, 0)], octave: 0, velocity: 0.16),
            padVelocity: 0.008,
            reverb: 0.45
        ),
        bars: section(.light, [("G", ""), ("Em", ""), ("C", ""), ("D", "")])
            + section(.light, lullabyA)
            + section(.full, lullabyB)
            + section(.full, lullabyA)
            + section(.full, lullabyB)
            + section(.full, [("C", "E6/2 D6"), ("D", "C6/1.5 A5/1.5")])
            + section(.light, [("G", "B5/3"), ("G", "G5/3")])
    )

    private static let lullabyA: [(chord: String, tune: String)] = [
        ("G", "B5/2 G5"),
        ("Em", "B5/1.5 A5/.5 G5"),
        ("C", "E5/2 G5"),
        ("D", "F#5/3"),
        ("G", "D5 G5 B5"),
        ("Em", "A5/1.5 G5/.5 E5"),
        ("D", "F#5 A5 C6"),
        ("G", "B5 G5/2")
    ]

    private static let lullabyB: [(chord: String, tune: String)] = [
        ("C", "E6/2 D6"),
        ("G", "D6/1.5 B5/.5 G5"),
        ("Am", "C6 B5 A5"),
        ("Em", "B5/2 G5"),
        ("C", "G5 A5 C6"),
        ("G", "B5/1.5 A5/.5 G5"),
        ("D", "A5/1.5 G5/.5 F#5"),
        ("D", "A5/3")
    ]
}
