# v02 proof and inspection

**Request.** v02 answers the owner's audition of v01.
- Keep themes 01–05 and the integrated v01 unchanged.
- Rework Noctyrax as two bigger, darker takes.
- Rework the three stingers away from the "cheery and cute" tone.

## Verification

The `scripts/v02/verify_dragons_v02.py versions/v02` command passes when run
with `--compare <fresh v02 build>` and `--v01-rebuild <fresh v01 build>`. The
full report is `versions/v02/VERIFICATION.json`. It checked:
- **Hashes.** 27 source/dependency hashes and 30 output hashes. All five scores
  regenerate exactly, and MIDI reads back exactly.
- **Structure.** Note bounds, string ranges and monophonic string lanes, with
  at most 16 melodic gates (14 in take A, 16 in take B).
- **Audio.** 32 kHz stereo Vorbis/FLAC/MP3 that decodes strictly. Durations,
  loudness, and sample and true-peak headroom.
- **Loops.** The 1.5 seam-ratio bound, plus the section-aware seam profile.
- **Stinger briefs.** Length, onset within 10 ms, a natural tail, no
  bell/pluck voices, and a low register.

| Piece | Length | Integrated (FLAC / Ogg) | Sample / true peak | Momentary max | Loudness range |
| --- | --- | --- | --- | --- | --- |
| Noctyrax take A (B♭, 88 BPM) | 87.27 s | −20.00 / −19.99 LUFS | −4.1 / −4.1 dB | −13.7 LUFS | 8.8 LU |
| Noctyrax take B (E, 132 BPM) | 87.27 s | −20.00 / −19.99 LUFS | −4.9 / −4.9 dB | −15.7 LUFS | 6.2 LU |
| Level Up | 3.47 s | −18.0 LUFS | −6.4 / −6.4 dB | −15.4 LUFS | n/a |
| Rare Reward | 2.74 s | −18.0 LUFS | −8.5 / −8.5 dB | −16.6 LUFS | n/a |
| Boss Defeated | 6.32 s | −18.0 LUFS | −5.5 / −5.5 dB | −14.0 LUFS | n/a |

**Standing out.** Themes 01–05 reach at most 2.5 LU of loudness range,
−17.3 LUFS momentary and −18.6 LUFS short-term. Both takes clear that by the
verifier's margins.

**Section loudness.**

| Take | Sections (LUFS) | Climax |
| --- | --- | --- |
| A | −23.2, −22.0, −20.1, −16.9, −25.2, −20.6 | Summit, bars 17–24 |
| B | −23.3, −21.6, −21.1, −23.2, −18.0, −18.7 | Bars 29–40 |

**Other checks.**
- **Seams.** Ogg seam ratios are 0.024 (A) and 0.125 (B), and both seam
  profiles sit within each piece's own transitions.
- **Harmony.** Audio chroma places the authored chord first in 27 of 32
  bars (A) and 39 of 48 (B).
- **Distinctness.** Take A (88 BPM, B♭) and take B (132 BPM, E) differ from
  each other, from themes 01–05 and from Thorns in tempo, tonic and opening
  interval signature.
- **Tone.**
  - Level Up and Boss Defeated are much darker than their v01 versions:
    spectral centroid 254 vs 469 Hz and 274 vs 316 Hz, with 73% and 67% of
    their energy below 250 Hz.
  - Rare Reward is brighter, at 843 Hz, because its glassy harmonics are
    intentional. Its harmony is a dissonant A-minor colour with a raised
    fourth and a flat ninth, not a major arpeggio.

## v01 integrity and determinism

**v01 integrity.**
- All 21 v01 source hashes and 54 v01 output hashes are unchanged.
- The v01 builder hashes the top-level `scripts/*.py`, `README.md`,
  `PROVENANCE.md` and `requirements.txt`. All of them are byte-identical to
  their state before v02 work began.
- The full `versions/v01` tree (58 files) is byte-identical to a snapshot
  taken before v02 work began.
- A fresh `scripts/build.py` rebuild is byte-identical to `versions/v01`
  across all 55 generated files.
- v01's own `verify_dragons.py` still passes.

The one file in `versions/v01` that no build produces is a Finder
`.DS_Store`, which appeared before v02 work and was left alone. The v02
comparison ignores OS metadata.

**Determinism.**
- A second, independent v02 build reproduced all 31 generated files
  byte-for-byte.
- The builder refuses to overwrite an existing directory.

## Inspection

The inspection is the standalone audio: see `versions/v02/AUDITION.md`. Godot
integration is the coordinator's step.

**Strike transients.** A transient scan found no discontinuities. Large-drum
and bell strikes carry short, intentional noise attacks with 1.5 ms onsets.
They read sharper than v01's softer kit.

**Toolchain.** Python 3.12.13, NumPy 2.3.5, mido 1.3.3 and FFmpeg 8.1.1.

**Not established.** Numeric checks do not establish musical quality, or how
realistic the synthesized choir and brass sound. Those need the owner's ears.
