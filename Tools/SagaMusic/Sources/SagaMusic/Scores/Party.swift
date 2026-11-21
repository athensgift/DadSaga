extension Score {
    /// A bouncy tune in F major at 120 beats a minute, for birthdays: ukulele oom-pahs, a marimba on the tune, light
    /// drums. Intro, A twice (the second with drums), B, A, B, A with drums, B again and a short ending.
    static let party = Score(
        id: "candles-and-confetti",
        beatsPerMinute: 120,
        beatsPerBar: 4,
        band: Band(
            comping: Comping(
                instrument: .pluck,
                steps: [Step(0, 0), Step(0.5, 2, 3), Step(1, 1), Step(1.5, 2, 3),
                        Step(2, 0), Step(2.5, 2, 3), Step(3, 1), Step(3.5, 2, 3)],
                octave: 12, velocity: 0.11, accentEvery: 1, pan: -0.3
            ),
            lead: Lead(instrument: .marimba, velocity: 0.34, pan: 0.2),
            bass: BassLine(steps: [Step(0, 0), Step(1.5, 0), Step(2, 1), Step(3, 0)], octave: 0, velocity: 0.2),
            padVelocity: 0.004,
            drums: Drums(kick: [0, 2], snare: [1, 3], hat: [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5], velocity: 0.3),
            reverb: 0.25
        ),
        bars: section(.light, [("F", ""), ("C", ""), ("Dm", ""), ("Bb", "")])
            + section(.full, partyA(ending: ("C", "E5 G5 C5/2")))
            + section(.driving, partyA(ending: ("F", "F5 C5/.5 A4/.5 F4/2")))
            + section(.driving, partyB)
            + section(.full, partyA(ending: ("F", "F5 C5/.5 A4/.5 F4/2")))
            + section(.driving, partyB)
            + section(.driving, partyA(ending: ("F", "F5 C5/.5 A4/.5 F4/2")))
            + section(.driving, partyB)
            + section(.full, [("F", "F5 A5 C6/2"), ("Bb", "Bb5 A5 G5/2")])
            + section(.light, [("C", "E5 G5 Bb5/2"), ("F", "F5/4")])
    )

    private static func partyA(ending: (chord: String, tune: String)) -> [(chord: String, tune: String)] {
        [
            ("F", "C5/.5 A4/.5 C5/.5 F5/.5 E5 C5"),
            ("C", "D5/.5 C5/.5 Bb4/.5 G4/.5 C5/2"),
            ("Dm", "A4/.5 D5/.5 F5/.5 D5/.5 A5 F5"),
            ("Bb", "G5/.5 F5/.5 D5/.5 Bb4/.5 F5/2"),
            ("F", "C5/.5 A4/.5 C5/.5 F5/.5 A5 G5/.5 F5/.5"),
            ("C", "E5/.5 G5/.5 C6 Bb5/.5 G5/.5 E5"),
            ("Bb", "D5/.5 F5/.5 Bb5 A5/.5 G5/.5 F5"),
            ending
        ]
    }

    private static let partyB: [(chord: String, tune: String)] = [
        ("Bb", "F5 Bb5 A5/.5 G5/.5 F5"),
        ("F", "A5/1.5 G5/.5 F5/2"),
        ("Gm", "G5/.5 A5/.5 Bb5/.5 A5/.5 G5 D5"),
        ("C", "E5/.5 F5/.5 G5 C5/2"),
        ("Bb", "D5/.5 F5/.5 Bb5 C6/.5 Bb5/.5 A5"),
        ("F", "A5/.5 G5/.5 F5 C5/2"),
        ("Gm", "Bb4/.5 D5/.5 G5 F5/.5 E5/.5 D5"),
        ("C", "C5/.5 D5/.5 E5/.5 G5/.5 C6/2")
    ]
}
