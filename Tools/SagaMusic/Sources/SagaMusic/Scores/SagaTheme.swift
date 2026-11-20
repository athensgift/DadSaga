extension Score {
    /// The first theme: a gentle tune in D major at 80 beats a minute.
    /// Intro (plucked chords alone), A (the tune), B (higher, with bass), A again, and an ending that settles on D.
    static let sagaTheme = Score(
        id: "saga-theme",
        beatsPerMinute: 80,
        beatsPerBar: 4,
        band: Band(
            comping: Comping(instrument: .pluck, steps: Step.arpeggio([0, 1, 2, 3, 2, 1, 2, 3], every: 0.5),
                             octave: 12, velocity: 0.16, accentEvery: 2, pan: -0.25),
            lead: Lead(instrument: .bell, velocity: 0.2, pan: 0.2),
            bass: BassLine(steps: [Step(0, 0), Step(2, 0)], octave: -12, velocity: 0.22),
            padVelocity: 0.007,
            reverb: 0.35
        ),
        bars: section(.light, [("D", ""), ("A", ""), ("Bm", ""), ("G", "")])
            + sagaA + sagaB + sagaA
            + section(.full, [("G", "G5/2 F#5/2"), ("D", "F#5/4")])
            + section(.light, [("A", "E5/4"), ("D", "D5/4")])
    )

    private static let sagaA = section(.light, [
        ("D", "F#5/1.5 E5/.5 D5 E5"),
        ("A", "C#5/2 E5 C#5"),
        ("Bm", "D5/1.5 C#5/.5 B4/2"),
        ("G", "B4 D5 G5/2")
    ]) + section(.full, [
        ("D", "F#5/1.5 G5/.5 A5 F#5"),
        ("A", "E5/2 C#5 E5"),
        ("G", "D5 B4 D5 G5"),
        ("A", "E5/3")
    ])

    private static let sagaB = section(.full, [
        ("G", "B5/2 A5 G5"),
        ("D", "A5/2 F#5/2"),
        ("A", "E5 F#5 A5 E5"),
        ("Bm", "F#5/3"),
        ("G", "G5 A5 B5/2"),
        ("D", "D6/2 A5/2"),
        ("Em", "G5 F#5 E5/2"),
        ("A", "C#5/2 E5 C#5")
    ])
}
