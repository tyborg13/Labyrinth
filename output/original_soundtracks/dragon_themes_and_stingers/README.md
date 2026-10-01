# Dragon boss themes and stingers (v01)

Six original boss loops, one per dragon, and three short stingers for Escape
the Umbra. They were requested as audition candidates only, so no game routing,
asset or production file changes. Every piece is an explicit symbolic score in
`scripts/dragon_scores.py`, rendered by the renderer family behind the approved
**Thorns in the Dark v02**. That keeps the themes in the same sound world as the
current boss cue while giving each dragon its own motif, key, tempo and texture.

| # | Piece | Key / mode | Tempo | Form | Loop |
| --- | --- | --- | --- | --- | --- |
| 1 | Zekarion, the Raging Tempest (lightning) | F# minor, Phrygian G / C#7(b9) strikes | 156 BPM | 32 bars | 49.23 s |
| 2 | Tharokh, the Worldspine (earth) | A minor with Phrygian B-flat | 64 BPM | 16 bars | 60.00 s |
| 3 | Vyraketh, the Cinder Crown (fire) | F harmonic minor | 138 BPM | 32 bars | 55.65 s |
| 4 | Vaeloryx, the Hollow Gale (air) | D Dorian, Lydian B-flat(#11) | 126 BPM (triplet feel) | 28 bars | 53.33 s |
| 5 | Iskaldra, the Rime Tyrant (ice) | C# minor, Neapolitan D | 76 BPM | 18 bars | 56.84 s |
| 6 | Noctyrax, the Last Eclipse (shadow, final) | B-flat minor / Phrygian | 96 BPM | 24 bars | 60.00 s |

Thorns is C minor at 116 BPM. None of the six themes shares its tonic or tempo,
and none shares a tonic or tempo with another theme. Each theme is mastered to
-20 LUFS integrated, the level of the approved tracks.

## Shared palette and mix

- **Strings.** Violin I, violin II and viola use the owner-approved procedural
  bowed-string synth from `string_ensemble_revisions`. Tharokh adds a
  cello-register lane, which is the same synth's viola body played low.
  This package adds one articulation, *measured tremolo*: a tempo-locked
  bow-change modulation, marked `tr` in the score. It runs at 16th or 32nd
  notes: 8.5-13 Hz in the themes, and a faster 17.6 Hz shimmer in Rare Reward.
- **Rhythm section.** Pad (`bowed_veil`), `hollow_bass`, `thread_pluck` and
  drums reuse the v01/v02 synthesis unchanged. The drums are kick (36) and tom
  (41), with a restrained noise snare (38) and crackle ticks (42) where noted.
  Iskaldra and Noctyrax add the FM `lantern_mallet` bell.
- **Balance.** At build time the builder recomputes the exact pre-master stem
  targets of the Thorns v02 mix from its parent score. Each stem is calibrated
  to one of those targets plus a small authored offset, stored in `score.json`
  under `mix`. As a result, lead, middle strings, bass and drums sit where they
  do in Thorns. The melody leads sit 0.7-1.4 LU over the combined second violin
  and viola (Thorns is 0.57 LU). Tharokh's cello lead sits 2.6 LU over its lone
  viola. The bass is about -24 LUFS inside the -20 mix.
- **Loops.** Each loop has an exact bar-length period. Release tails, the
  circular dark echo and the zero-phase filters wrap around the loop point, and
  a 2 ms endpoint taper follows the Thorns convention.
- **Limits.** At most six simultaneous melodic note gates, and monophonic string
  lanes.
- **Stingers.** They render linearly, not circularly, with a seeded synthetic
  hall tail. They are mastered to -18 LUFS integrated with a -3 dBFS sample-peak
  ceiling. For comparison, the game's `victory_resolution.wav` measures
  -17.6 LUFS.
- **Formats.** Everything is 32 kHz stereo: native Vorbis Ogg (q5), FLAC and
  192 kbps MP3, the same as the approved tracks.

## The themes

**1. Zekarion, the Raging Tempest.** F# minor, 156 BPM, the highest energy of
the six.
- **Motif.** A zigzag bolt, F#-C#-G-F#, in dotted sixteenths (3+3+3+3+2+2). Its
  G natural is a Phrygian flash.
- **Groove.** Plucks, bass, viola and second-violin stabs all accent 3+3+2
  eighths, which gives a jagged, off-balance pulse. Crackle ticks sit above it.
- **Form.**
  - Bars 1-8: statement over F#m, D7 (a German-sixth colour), C#7, then Bm,
    the Neapolitan G and C#7(b9).
  - Bars 9-16: the second violins shadow the motif in parallel fourths, and the
    motif moves onto B minor.
  - Bars 17-24, the eye of the storm: the motif in rhythmic augmentation,
    sequenced D, E, F#m, each time with a 4-3 suspension. Violin II and viola
    play tremolo, then a tom roll builds.
  - Bars 25-32: a full strike with backbeat, tutti Neapolitan stabs and a
    diminished fall back to bar 1.
- **Relation to Thorns.** The ensemble is the same, but everything else is
  faster, sharper and syncopated.

**2. Tharokh, the Worldspine.** A minor with a Phrygian B-flat, 64 BPM.
- **Motif.** A dotted march in the cello register: A . A-E | F-E-D-C |
  Bb-C-D-F | E-G#. The progression is i-VI-bII-V.
- **Texture.** The viola grinds in slurred eighths on semitones (A-Bb, D-E)
  under heavy *paired* kick strokes (DUM-DUM ... DUM-DUM) and low
  stone-like plucks.
- **Form.**
  - Bars 1-4: the low strings alone.
  - Bars 5-8: a slow violin descant enters.
  - Bars 9-12: "the spine rises". Cello and violin climb in sequence over
    F-G-Am while the viola plays tremolo.
  - Bars 13-16: the march in cello and violin, two octaves apart.
- **Relation to Thorns.** About half Thorns' tempo, with the melody moved down
  into the low strings.

**3. Vyraketh, the Cinder Crown.** F harmonic minor, 138 BPM.
- **Motif.** An "ember" cell: C up to F, an E-F flick of the leading tone,
  then a climb to Ab. It rises a third each bar over Fm-Ab-Bbm-C7(b9).
- **Groove.** Galloping plucks (eighth and two sixteenths) and pumping bass.
  The percussion is heavier than in the other themes and is terraced.
- **Form.**
  - Bars 1-8: kick and toms only.
  - Bars 9-16: the backbeat is added, the cell is harmonized in sixths, and a
    Neapolitan G-flat flares.
  - Bars 17-24: a soaring violin over hammered 3+3+2 strings (Db-Eb-Fm).
  - Bars 25-32: the cell climbs *chromatically* through parallel minor chords,
    Fm-Gbm-Gm-Abm-Am-Bbm, into C7, with tom rolls.
- **Dynamics.** Section loudness rises -21.0 → -20.3 → -19.6 → -19.5 LUFS.

**4. Vaeloryx, the Hollow Gale.** D Dorian, 126 BPM in a compound triplet
feel.
- **Motif.** A long D5, a rushing triplet gust up to the Dorian B natural, then
  a fall.
- **Harmony.** Dm9, G/D and C are shadowed by a Lydian Bbmaj7(#11). An
  E7/G# with a G-to-G# clash supplies the threat.
- **Texture.** Violin II throws six-note triplet gusts every bar, and plucks
  swirl in triplet arpeggios. The drums are light, the panning wider and the
  echo larger.
- **Form.**
  - Bars 1-8: theme.
  - Bars 9-16: a wide second theme peaking on the Lydian E6.
  - Bars 17-20: a hollow lull, about 2.3 LU quieter.
  - Bars 21-28: the theme with counter-gusts in contrary motion.

**5. Iskaldra, the Rime Tyrant.** C# minor, 76 BPM.
- **Motif.** In glassy, low-vibrato high violin: G#-C#-D#-E (5-1-2-3), answered
  by D# over Amaj7 (a Lydian chill).
- **Texture.** A music-box bell ostinato replaces the pad, with crystalline
  high plucks and a slow kick-and-tom pulse. A Neapolitan D major gives a cold
  shock.
- **Form.**
  - Bars 1-8: statement.
  - Bars 9-12: a G# pedal with tremolo inner strings under a chromatic high
    descent, E-D#-D-C#-B#.
  - Bars 13-16: return.
  - Bars 17-18: the motif alone on bells, with a pickup into the loop.

**6. Noctyrax, the Last Eclipse.** B-flat minor / Phrygian, 96 BPM, the
darkest and grandest.
- **Motif.** It deliberately quotes Thorns in distorted form. Thorns'
  C-G-Eb-D | Eb-C becomes Bb-F-Db-**Cb** | Db-Bb: a whole tone lower, twice
  as slow, with the Phrygian flattened second. The first 16 intervals match
  Thorns' contour except the two ♭2 steps. The Thorns C-G-D-G pluck
  ostinato likewise returns as Bb-F-Cb-F.
- **Harmony.** i-i-bVI-V mirrors Thorns' Cm-Cm-Ab-G7.
- **Form.**
  - Bars 1-4: eclipse. A Bb pedal, a tolling bell and creeping F/Gb tremolo.
  - Bars 5-12: the quote, then Ebm and the Neapolitan Cb.
  - Bars 13-16: a chromatic build, Gb, Eb/G, Ab, A dim7, with a tom roll.
  - Bars 17-22: the climax. The quote an octave higher in octaves and thirds,
    peaking on F6 over F7(b9).
  - Bars 23-24: a Phrygian collapse.
- **Dynamics.** The loudness arc runs -23.3 → -20.5 → -19.5 → **-18.1** →
  -20.9 LUFS.

## The stingers

- **Level Up** (3.42 s, D major, 120 BPM). A warm IV-V-I: a stepwise violin
  rise with a chromatic G-G#-A lift into a sustained D chord, with an
  arpeggiated pluck, a soft tom pickup and a bell sparkle.
- **Rare Reward** (2.91 s, E-flat Lydian, 132 BPM). A bell cascade,
  Bb-D-F-A-Bb-D-F, over pianissimo tremolo harmonics. It ends on the
  unresolved #11 so it stays mysterious.
- **Boss Defeated** (6.77 s, C major). Parallel A-flat and B-flat triads, bVI
  and bVII, are hammered with heavy kick and tom hits into a C major Picardy
  arrival. Bells climb G-C-E and the violin leaps to C6. It is weightier than
  the existing victory sound.

## Rebuild and verify

With Python 3.12, FFmpeg 8.1 (native Vorbis and libmp3lame) and
`requirements.txt` (music21 is used only by the verifier):

```sh
python3.12 -m venv /tmp/umbra-dragons-env
/tmp/umbra-dragons-env/bin/pip install -r output/original_soundtracks/dragon_themes_and_stingers/requirements.txt
/tmp/umbra-dragons-env/bin/python output/original_soundtracks/dragon_themes_and_stingers/scripts/build.py --output-dir /tmp/umbra-dragons-fresh
/tmp/umbra-dragons-env/bin/python output/original_soundtracks/dragon_themes_and_stingers/scripts/verify_dragons.py /tmp/umbra-dragons-fresh \
    --report /tmp/umbra-dragons-fresh/VERIFICATION.json --compare output/original_soundtracks/dragon_themes_and_stingers/versions/v01
```

The output directory must not exist, and `--only` builds a development subset
that the verifier rejects. Each `versions/v01/<NN_slug>/` folder holds:
- `arrangement.mid`
- the expanded `score.json`, with patches, mix plan, harmony, sections and
  identity
- `preview.flac`, `preview.ogg` and `preview.mp3`
- `render.json`: stem calibration, balance, per-stem peaks, circular continuity,
  and decoded loudness/peak/seam or tail measurements for every format

`SOURCES.json` freezes input and output hashes. `VERIFICATION.json` is the
verifier report, and `AUDITION.md` is the listening guide.

The verifier rejects:
- source or output drift, or scores that do not regenerate exactly
- MIDI that does not read back exactly
- notes out of bounds or out of string range, non-monophonic string lanes, or
  more than six gates
- wrong formats (anything but 32 kHz stereo Vorbis/FLAC/MP3) or durations
- themes outside -20 ± 1 LUFS, or headroom under 1 dB (sample and true peak)
- loop seams that exceed the sample-delta bound or are more abrupt than the
  piece's own internal transitions and section boundaries
- stingers that are too long or short, start late, or end in a hard cut
- shared tempos, tonics or opening lead intervals, among the themes or with
  Thorns
- rendered chords that do not track the authored harmony (chroma rank)
- a Noctyrax without its build to the climax

Generic MIDI players reproduce notes and rhythm, but only the renderer produces
the intended sound. Whether the instruments sound real, how the mix blends and
how the loop feels are listening judgments for the owner. Game integration and
a Godot fixture fall outside this audition.
