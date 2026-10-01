# Audition guide: v02 (Noctyrax takes A/B and dark stingers)

All paths are under
`output/original_soundtracks/dragon_themes_and_stingers/versions/v02/`.

**Which file to open.**
- **MP3** for a quick listen.
- **Ogg** to hear exactly what would ship (native Vorbis, 32 kHz stereo).
- **FLAC** as the lossless reference.

To judge a loop seam, loop the Ogg or FLAC gaplessly. MP3 padding adds a gap
at the loop point.

**Levels.** Both Noctyrax takes are at −20 LUFS integrated, like every other
theme, and the climaxes are where they stand out. A/B them against v01
Noctyrax (`../v01/06_noctyrax_the_last_eclipse/`) and against any other dragon.
The stingers are at −18 LUFS, like v01's.

## Noctyrax, the Last Eclipse: pick A or B

New voices in both takes: a synthesized choir, low brass, taiko, timpani, a
tolling bell, and low strings in octaves.

**Take A, "Eclipse Requiem"** (B♭ minor / Phrygian, 88 BPM, 87 s)
- `06a_noctyrax_the_last_eclipse_take_a/preview.mp3` | `.ogg` | `.flac`
- **0 s:** the loop opens on a single huge hit, then hushes into a tolling,
  humming eclipse.
- **About 11 s:** the low-string ostinato starts marching. Low brass sings the
  Thorns tune "eclipsed", and the women's choir takes it up.
- **About 33 s:** a chromatic rise with brass swells and a timpani roll.
- **About 44 s: the summit.** High violins and choir over three octaves of
  ostinato, brass chorale and full taiko. It is the loudest passage in the
  soundtrack, peaking on a high G♭.
- **About 65 s:** the requiem. The choir sings the motif almost alone over
  bells.
- **About 76 s:** the storm gathers back into the opening hit.
- **Question:** grand and ceremonial enough? Are the quiet valleys right for a
  boss fight?

**Take B, "Black Sun Onslaught"** (E Phrygian, 132 BPM, 87 s)
- `06b_noctyrax_the_last_eclipse_take_b/preview.mp3` | `.ogg` | `.flac`
- **0 s:** relentless sixteenth-note low strings, syncopated taiko and brass
  rising from the depths. It never really stops.
- **About 7 s:** choir chants hit the accents, and the violins hurl Thorns'
  opening bars with a flattened second.
- **About 22 s:** the "Black Sun" anthem in brass and choir over the
  ostinato.
- **About 36 s:** the breakdown. The viola continues alone under a whispered
  choir and glassy harmonics, then it builds.
- **About 51 s: the climax.** The anthem two octaves up in the violins, with
  full choir, brass chorale and taiko.
- **About 73 s:** tutti hits and a B7 roll back into the loop.
- **Question:** does the drive feel like the final battle? Is the ostinato
  present enough?

## Stingers v02 (one-shot)

The brief: no bright bells, plucks or major-key arpeggios. Low, weighty and
modal.

**Level Up** (3.5 s): `07_stinger_level_up/preview.mp3` | `.ogg` | `.flac`
- A solemn low-string swell on B♭ settles onto a bare D–A fifth.
- A deep bell toll, timpani, and a brass and men's-choir bloom arrive with it.
- The violins sink B♭→A: power earned at a cost.

**Rare Reward** (2.7 s): `08_stinger_rare_reward/preview.mp3` | `.ogg` | `.flac`
- Glassy string harmonics shimmer over a low drone.
- A raised fourth and a whispered flat-ninth choir note never resolve:
  dangerous and precious.

**Boss Defeated** (6.3 s): `09_stinger_boss_defeated/preview.mp3` | `.ogg` | `.flac`
- A crushing C-minor impact, an A♭ swell and a G-major dominant.
- Then a hard-won bare C fifth, with a faint Picardy E in the choir, a second
  bell toll and a long dark tail.

## Useful feedback

- A or B? Or one take's form with the other's tempo or drive?
- Choir and brass realism: these are synthesized voices.
- Should the quiet passages be shallower or deeper?
- Are the stinger lengths and the darkness right?

The scores are in `../../scripts/v02/scores_dragons_v02.py`, so any revision is
a quick, reproducible edit.
