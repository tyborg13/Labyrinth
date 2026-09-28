# Ember Hearth audio palette, revision 2

The hearth belongs to the same physical, dark-fantasy space as the existing UI.
Hover is a muted cloth/paper tick; selection a rounded finger/clasp contact;
arrival and departure breathe with the fire. Strength has a weighted clasp and
a short air swell. Recovery is a soft, connected ripple of air with an opening
filter, not a melody. This replaces the initial chipper sine-note palette after
user audition. No runtime timings or gameplay behavior change.

## Existing project sources

All source WAVs are already shipped in this repository. The new files are
filtered excerpts of those assets; no new sample pack, download, generated
recording, or external source is introduced. Their existing rights/provenance
continue to apply.

| Source relative to `assets/audio/sfx/` | Use |
| --- | --- |
| `card_draw_deal.wav` | Cloth/paper texture for hover, selection, arrival and departure |
| `card_play_take.wav` | Dry selection contact |
| `item_equip.wav` | Strength clasp/body |
| `elemental/air_attack.wav` | Soft filtered air for healing and Strength, excluding the initial attack |
| `run/campfire_loop.wav` | Brief warm fire textures for arrival and departure |

The generator documents every excerpt, speed, filter and envelope. Source
hashes and output hashes are recorded when `--report` is supplied. Down-pitching,
low-pass filtering and smooth transient saturation round the recorded attacks.
There are no oscillators, musical-note sequences, feedback delays or added
reverb. UI playback stays on the dry UI SFX bus, with the existing global SFX
headroom, volume and mute behavior.

## Healing timing

The unchanged board effect has five rising pluses. In
`CombatBoardView._draw_heal_cast_effect`, each starts when
`progress * 1.30 - index * 0.12` becomes positive. At the hearth's normal
0.90-second result duration, pulse starts are 0, 0.0831, 0.1662, 0.2492 and
0.3323 seconds. Each airy pulse has a 26 ms attack and overlapping rounded tail;
the opening filter supplies lift without discrete pitched notes. A quiet
exhalation joins the pulses. The 0.95-second cue ends during the existing panel
fade. Reduced motion keeps its stationary plus pose and the same gentle sound.

## Rebuild and verify

```sh
python3 tools/generate_ember_hearth_sfx.py --report /private/tmp/hearth-audio.json
```

`--output-dir` supports a separate regeneration directory for byte comparison.
All files are mono PCM16 at 44.1 kHz, peak at or below -4.4 dBFS before game gain,
with exact zero endpoints and a faded tail. Their existing durations are kept.
Mix gains live in `scripts/run_sfx_library.gd`; recovery has more presence than
focus, while arrival and departure stay under it. The world fire loop and
other game audio are unchanged.
