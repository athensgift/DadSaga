# ADR-0052: Every saga track outlasts the longest film the content allows

**Status:** Accepted (2026-11-21). The owner asked for every track to be at least 130 seconds, the same pieces, with a
test that fails when the content outgrows the music. Changes ADR-0036 §8 and ADR-0046 §1 and §7 (a track's length is
no longer "at least 95 seconds" but at least the longest film).

## Context
- A film is at most 90 seconds, but firsts are never dropped: when they don't fit, everything else goes and each first
  gets shorter, down to 3 seconds (ADR-0036 §2). So the longest film is the opening (3.5 s), a chapter card for each
  world (2.5 s), every first at 3 s and the credits (6 s). A first counts once per child, so "every first" is every
  first in the content, including any a later card set stops offering: a saga that captured it still shows it.
- Today's content (24 firsts, 4 worlds) allows 91.5 s. The v1 card set being prepared (34 firsts in the JSON, 5 worlds) allows 3.5 + 12.5 + 102 + 6 = 124 s.
- The five tracks last 100 to 104 seconds. `FilmKit` loops music that is shorter than the film, so a long film would
  start its track again from the intro and fade out in the middle of the second pass.
- The tracks are rendered from scores by `Tools/SagaMusic` (ADR-0036 §8, ADR-0046): the same score always renders the
  same sound.

## Decision
1. **Each track gets one more pass through its own sections, before its own ending.** The opening, the key, the tempo,
   the band, the title and the mood stay the same (ADR-0046 §1), and so do the first seconds, which the preview and a
   short film play. The scores change in `Tools/SagaMusic`, and the files are rendered and encoded again with it.

   | id | Added before the ending | Length |
   |---|---|---|
   | `saga-theme` | B, A | 148 s |
   | `candles-and-confetti` | A with drums, B | 132 s |
   | `music-box-lullaby` | A alone, B | 144 s |
   | `great-adventure` | B, A | 138.4 s |
   | `like-yesterday` | A alone, B | 144 s |

   Loudness stays within 0.4 dB of the earlier renders (−13.2 to −15.2 dBFS RMS).
2. **A test measures the music against the content, not against a number.** A Data test loads the bundled catalog,
   gives a child every first, each with all its photos, spread over every world, and more quests and bosses than fit,
   and makes the film with `SagaStoryboard`, the film's own rules. It checks that the film kept every first and that
   every bundled track lasts at least as long as that film. It holds no count of firsts or worlds, so a branch that adds
   content is checked against its own content. It replaces the 95-second check.
3. Nothing about the film changes: no first is dropped, the floor stays at 3 seconds, and `FilmKit` keeps looping as
   its own rule for any music shorter than its film; the app's music never needs it.

## Rejected
- **Dropping firsts or a lower floor** to fit the music: ADR-0036 §2 keeps every first, at a length that can be read.
- **A fixed "at least 130 seconds" check.** It wouldn't notice content that outgrows 130 seconds.
- **Stretching the audio.** It changes the tempo or the pitch: not the same piece.
- **A crossfaded loop.** A second pass would still restart the intro mid-film.

## Consequences
- With the v1 card set the shortest track (132 s) outlasts the longest film (124 s) by 8 seconds: room for two more
  firsts, or a world and one first. When the test fails, the shortest track gets another section with the tool.
- The app's music grows from about 7.3 MB to about 10.2 MB. The widget carries none of it.
- Each track sounds the same as before for its first passes; only a film longer than the old track, or someone who
  listens to the end, hears the added pass.
