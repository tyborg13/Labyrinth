# Audition guide: dragon themes and stingers v01

**Which file to open.**
- **MP3** for a quick listen.
- **Ogg** to hear exactly what the game would ship. It is native Vorbis,
  32 kHz stereo, like the approved tracks.
- **FLAC** as the lossless reference.

**Loop playback.** To judge a seam, loop the Ogg or FLAC in a player with
gapless looping. MP3 adds encoder padding, so it clicks or gaps at the loop
point even when the loop itself is clean.

**Levels.** Every theme is at -20 LUFS, the same as the approved tracks, so you
can A/B any of them against the current boss cue,
`assets/audio/music/thorns_in_the_dark_v02.ogg`. The stingers are at -18 LUFS,
roughly as loud as the game's existing victory sound.

**Paths.** All paths are relative to the repository root, under
`output/original_soundtracks/dragon_themes_and_stingers/versions/v01/`.

## Boss themes (seamless loops)

**1. Zekarion, the Raging Tempest** (lightning; F# minor, 156 BPM, 49 s)
- `01_zekarion_the_raging_tempest/preview.mp3` | `.ogg` | `.flac`
- **The motif:** a jagged F#-C#-G-F# zigzag in dotted sixteenths, heard
  against stabs that accent 3+3+2.
- **Bar 9:** the second violins shadow the motif in fourths.
- **About 25 s:** the "eye of the storm". The motif slows to half speed over
  tremolo strings, then a tom roll launches the full strike.
- **Question:** does it feel like the highest-energy fight?

**2. Tharokh, the Worldspine** (earth; A minor with a Phrygian B-flat, 64 BPM, 60 s)
- `02_tharokh_the_worldspine/preview.mp3` | `.ogg` | `.flac`
- **The texture:** a slow, massive cello-register march over paired "DUM-DUM"
  kicks and a viola grinding on semitones.
- **About 15 s:** a high violin descant enters.
- **About 30 s:** cello and violin climb in sequence.
- **Last phrase:** the march rings out two octaves apart.
- **Question:** is it heavy without being sluggish?

**3. Vyraketh, the Cinder Crown** (fire; F minor, 138 BPM, 56 s)
- `03_vyraketh_the_cinder_crown/preview.mp3` | `.ogg` | `.flac`
- **The motif:** an "ember" figure that climbs a third every bar, over a
  galloping pluck.
- **Build:** the drums are terraced and grow through the loop.
- **About 42 s:** the ember figure climbs by semitones through six minor
  chords, with tom rolls. That climb is the hottest moment.

**4. Vaeloryx, the Hollow Gale** (air; D Dorian, 126 BPM triplet feel, 53 s)
- `04_vaeloryx_the_hollow_gale/preview.mp3` | `.ogg` | `.flac`
- **The texture:** long held notes broken by triplet "gusts". The stereo is
  wider and the drums lighter.
- **Harmony:** a floating Lydian colour on B-flat, and a threatening E7/G#.
- **About 30 s:** a brief hollow lull, then the theme returns with
  counter-gusts moving the other way.
- **Question:** is it airy but still dangerous?

**5. Iskaldra, the Rime Tyrant** (ice; C# minor, 76 BPM, 57 s)
- `05_iskaldra_the_rime_tyrant/preview.mp3` | `.ogg` | `.flac`
- **The texture:** a music-box bell ostinato, glassy low-vibrato high violins,
  crystal plucks and a slow pulse.
- **About 25 s:** the "frost" section. Tremolo over a G# pedal and a chromatic
  high descent.
- **Before the loop:** the ending hands the motif to the bells alone, then
  picks up back into the start.
- **Loop check:** listen for the join.

**6. Noctyrax, the Last Eclipse** (shadow, final boss; B-flat minor / Phrygian, 96 BPM, 60 s)
- `06_noctyrax_the_last_eclipse/preview.mp3` | `.ogg` | `.flac`
- **Opening:** a dark intro with a tolling bell and creeping tremolo.
- **About 10 s:** Thorns in the Dark's opening tune comes back "eclipsed":
  slower, lower, and with a flattened second note.
- **Build:** a chromatic build into the grand climax at about 40 s, the loudest
  passage of the six themes.
- **Question:** does the quote read as Thorns turned sinister, or should it be
  more or less obvious?

## Stingers (one-shot, natural tails)

**Level Up** (3.4 s)
- `07_stinger_level_up/preview.mp3` | `.ogg` | `.flac`
- A warm IV-V-I rise, with a little chromatic lift before the bright D major
  chord and a bell sparkle.

**Rare Reward** (2.9 s)
- `08_stinger_rare_reward/preview.mp3` | `.ogg` | `.flac`
- A shimmering bell cascade over hushed tremolo. It ends unresolved, on a
  Lydian note, to keep the "what did I find?" mystery.

**Boss Defeated** (6.8 s)
- `09_stinger_boss_defeated/preview.mp3` | `.ogg` | `.flac`
- Three heavy hits, A-flat → B-flat → C major, with big drums. Bells climb and
  the violin leaps up as the chord resolves. It is meant to feel weightier than
  a normal win.

**Tails.** All three start instantly and fade on their own reverb. None is cut
off.

## Useful feedback

- Does each theme fit its dragon?
- Should any tempo or intensity change?
- Is any lead too present or too buried?
- Are the stinger lengths right?

The source is `scripts/dragon_scores.py`, so a revision is a quick,
reproducible edit.
