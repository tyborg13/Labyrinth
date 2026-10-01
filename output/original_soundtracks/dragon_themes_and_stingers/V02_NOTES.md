# Dragon themes and stingers: v02

v02 answers the owner's audition of v01.

**What the owner asked for.**
- Themes 01–05 are kept exactly as they are.
- **Noctyrax** must be more epic and stand out. It comes as two contrasting
  takes, A and B.
- All three **stingers** were "too cheery and cute". They are reworked for a
  dark-fantasy dungeon tone.

**Where things live.** `versions/v02/` holds only these five pieces. The
folder names keep their roles:
- `06a_…take_a`
- `06b_…take_b`
- `07_stinger_level_up`
- `08_stinger_rare_reward`
- `09_stinger_boss_defeated`

Each folder has `preview.ogg`, `preview.flac`, `preview.mp3`,
`arrangement.mid`, `score.json` and `render.json`.

## v01 is untouched

The v01 builder hashes every top-level `scripts/*.py`, plus `README.md`,
`PROVENANCE.md` and `requirements.txt`. v02 therefore leaves all of those
exactly as they were:
- **Code.** The v02 code lives in `scripts/v02/`, which v01's non-recursive
  glob does not see. It imports the v01 modules read-only. `scripts/build.py`
  is loaded under the module name `dragon_build_v01`, because the engine
  already owns the name `build`.
- **Docs.** The v02 documents are separate files (`V02_*.md`).
- **Proof.** `verify_dragons_v02.py --v01-rebuild <dir>` checks that every v01
  source and output hash is unchanged. It also checks that a fresh
  `scripts/build.py` run is byte-identical to `versions/v01`.

## Noctyrax, the Last Eclipse: two takes

Both takes widen the Thorns-family palette into a full ensemble:
- violins and viola
- **low strings in octaves**: cello, plus a contrabass played by the same
  bowed synth an octave lower
- a **formant choir** in two sections: men "oh/ah/oo", women "ah"
- a **low brass section**
- **taiko** (o-daiko and two smaller drums)
- **timpani**, with rolls
- a deep **tolling bell**

Both keep the Noctyrax identity: Thorns' opening tune "eclipsed", with its
second degree flattened. Both loop seamlessly and master to −20 LUFS
integrated, the same as the other combat cues at −5.5 dB playback gain. Their
loudness range is much wider than the other themes: quiet valleys and a climax
several dB louder. I chose not to raise the integrated level, because the
climaxes already read clearly louder than any other theme. Each take is about
87 seconds.

**Take A, "Eclipse Requiem"**: B-flat minor / Phrygian, 88 BPM, 32 bars. A
processional, cathedral-scale take.
- **1–4: Impact and eclipse.** The loop restarts on one huge hit: taiko,
  timpani, brass, strings and bell together. It hushes into a B-flat pedal,
  with a humming men's choir, tolling bell, heartbeat drums and high creeping
  tremolo.
- **5–12: Procession.** A relentless low-string ostinato (root, Phrygian
  C-flat, a kick at the bar end) runs over taiko. Low brass intones the
  eclipsed Thorns motif B♭–F–D♭–C♭ | D♭–B♭, and the women's choir takes it up
  an octave higher.
- **13–16: Chromatic rise.** G♭, E♭/G, A♭, A dim7, with brass swells, tremolo
  and a timpani roll.
- **17–24: Summit.** High violins and choir carry a new long-breathed melody
  that peaks on G♭6. The ostinato runs in three octaves (viola, cello,
  contrabass) under a brass chorale, with full taiko and timpani. This is the
  loudest passage in the soundtrack.
- **25–28: Requiem.** The choir sings the motif almost alone over a drone and
  bells.
- **29–32: Gathering storm.** The ostinato, brass and choir crescendo through
  A dim7 and F7(♭9), and a timpani roll leads back into the impact.

**Take B, "Black Sun Onslaught"**: E Phrygian, 132 BPM, 48 bars. A relentless,
driving take.
- **1–4: Engine.** Sixteenth-note viola and cello churn on E–F–G with a
  B-flat tritone kick, over an E pedal, syncopated taiko and brass rising from
  E1.
- **5–12: Chants.** Choir chants hit the accents. The violins hurl Thorns'
  first two bars almost verbatim in rhythm, but in E Phrygian: E–B–G–F–G–E.
- **13–20: Black Sun anthem.** Low brass and choir sing the anthem over the
  ostinato: Em–F–G–F | Em–Dm–C–F.
- **21–28: Breakdown.** The viola continues alone, under a whispered
  semitone choir cluster and glassy harmonics. Then Am–B♭–B7 builds over a
  timpani roll.
- **29–40: Climax.** The anthem returns two octaves up in the violins, with the
  choir fortissimo, the brass chorale on the eclipse motif, low strings in
  octaves and full taiko.
- **41–48: Coda.** Tutti 3+3+2 hits, the motif once more, and a B7 roll back
  into the engine.

**How A and B differ.** Take A is ceremonial: slow, with a tolling summit and a
deep valley. Take B never lets go: fast, rhythmic and modal. They also differ
in tempo (88 vs 132 BPM) and tonic (B♭ vs E). Neither shares a tempo, tonic or
opening with the other dragons or with Thorns.

## The stingers (v02)

No bright bells, plucks, bouncy figures or major-key arpeggios. Every one
reaches into the low register. They are mastered as in v01: −18 LUFS
integrated, a −3 dBFS sample-peak ceiling, prompt onset, and a hall tail that
decays naturally. The tail is trimmed only once it is inaudible.

- **Level Up** (D, 80 BPM). Power earned at a cost.
  - Low strings swell on B-flat over a soft taiko.
  - They settle onto a bare D–A open fifth, with a tolling bell, timpani, and
    a brass and men's-choir bloom.
  - Meanwhile the top line sinks B♭→A.
- **Rare Reward** (80 BPM). Something dangerous and precious.
  - Glassy E6/C6 string harmonics shimmer in tremolo over an A–E drone.
  - A raised-fourth D♯ and a whispered flat-ninth B♭ in the choir enter
    against it, and nothing resolves.
- **Boss Defeated** (60 BPM). Grim triumph.
  - A crushing C-minor impact (taiko, timpani, brass sforzando, full strings,
    choir, bell).
  - An A-flat swell, then a G-major dominant whose B-natural rises in the
    brass while the violins fall E♭–D–C.
  - The arrival is a hard-won bare C fifth, with a faint Picardy E in the
    women's choir, a second bell toll and a long dark tail.

## New procedural instruments (`scripts/v02/instruments_dragons_v02.py`)

- **Choir.** Six singers per note. Each sings glottal harmonics shaped by
  vowel formants (oh/ah/oo, men's and women's sets), with seeded detune,
  vibrato, drift, onset staggering, shimmer and formant-shaped breath noise.
- **Brass.** Three players. Wavetables crossfade from soft to blazing as the
  dynamic rises, with a bell-formant bump, onset scoop, gentle saturation and
  a breath burst. Shapes are swell, sforzando and fade.
- **Taiko.** Modal membrane with a pitch drop, a band-limited "thud" and a
  stick crack.
- **Timpani.** Near-harmonic kettle modes with a mallet attack. Rolls are
  played as seeded single strokes.
- **Bell.** Hum, prime, minor-third tierce, quint, nominal and upper partials,
  each with a weaker beating partner and a soft strike.
- **Strike onsets.** All strikes have 1.5 ms raised-cosine onsets.
- **Strings.** They gain swell, sforzando and fade shapes, alongside v01's
  tremolo.
- **Loops.** A circular convolution hall: the v01 seeded hall impulse,
  wrapped over the loop period.
- **MIDI.** Exported with percussion on channel 10.

## Rebuild and verify

```sh
PKG=output/original_soundtracks/dragon_themes_and_stingers
python $PKG/scripts/v02/build_dragons_v02.py --output-dir /tmp/dragons-v02-fresh
python $PKG/scripts/build.py --output-dir /tmp/dragons-v01-fresh
python $PKG/scripts/v02/verify_dragons_v02.py $PKG/versions/v02 --compare /tmp/dragons-v02-fresh \
    --v01-rebuild /tmp/dragons-v01-fresh --report /tmp/dragons-v02-fresh/VERIFICATION.json
```

Use Python 3.12, FFmpeg 8.1 and `requirements.txt`. Output directories must
not exist.

The verifier applies v01's checks to the new pieces:
- source and output hashes
- exact score and MIDI regeneration
- 32 kHz stereo Vorbis/FLAC/MP3
- loudness and headroom
- seams: the sample-delta check plus the section-aware seam profile
- stinger length, onset and tail

It adds checks for:
- the 75–100 s final-boss loop length
- at most 16 melodic gates (a final-boss exception to v01's six)
- unique tempo, tonic and opening against themes 01–05 and Thorns
- "stands out": loudness range at least 2 LU larger and momentary maximum at
  least 1.5 LU louder than every other theme, plus a real climax
- no bell or pluck voices and a low register in the stingers

The verifier also records tone comparisons with the v01 stingers.

How the synthesized choir and brass actually sound is the owner's judgment.
They are procedural, so they evoke voices and brass rather than claiming
recorded realism.
