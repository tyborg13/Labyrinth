# sfx-00 — Sound lab: slice, analyse, audition and build SFX from licence-clean libraries

## Header
- Goal: tooling that lets the director (who cannot listen) choose sounds by measured traits, lets the owner
  audition candidates on a web page, and turns approved picks into game-ready, loudness-matched assets with
  provenance. No game code in this unit.
- Base: `codex/peer-benchmark`. Depends on: nothing.
- Sources (read-only, outside git): `/Users/borgerding/workspace/Labyrinth/output/sfx-sources-2026-10-12/`
  (`sonniss_gdc/`, `kenney/`, `opengameart/`; `CATALOGUE.md`, `INDEX.tsv`, per-source `LICENSE.txt`). NEVER read from
  `output/sfx-sources-excluded-2026-10-12/` (Mixkit is excluded; the tools must refuse paths under it).
- Python: use the venv `/Users/borgerding/.cache/umbra-sfx/venv/bin/python` (numpy, scipy, soundfile, pyloudnorm) and
  `ffmpeg`/`ffprobe` from PATH (`-threads 2`, never more than 4 ffmpeg processes at once — machine limit). Do not
  install packages.
- Owned files: new `tools/sfx_lab/` (package: `index.py`, `slice.py`, `features.py`, `audition.py`, `build.py`,
  `common.py`, `README.md`), new `tests/test_sfx_lab.py` (+ tiny synthetic fixtures generated in the test, not
  committed audio), new `spec/sfx_pipeline.md`.
- Rules: deterministic outputs; licence id carried with every file; no network; `TODO_DESIGN_<name>` for anything
  undecided.
- Contract: risk tier low (tooling). Acceptance: (1) index + slice + features over a source tree; (2) audition page
  generator; (3) build from a picks file with loudness targets and provenance; (4) tests pass.

## Change (numbered, testable)
1. **Index** (`index.py --sources <dir> --out <dir>/index.json`): every audio file (wav/ogg/flac/mp3) under
   sonniss_gdc, kenney, opengameart with: relative path, source id, licence id (from the source folder: `sonniss_gdc`
   → "Sonniss GDC Bundle licence", `kenney`/`opengameart` → "CC0-1.0"), duration, sample rate, channels, bit depth,
   sha256. Skip `.DS_Store`, `__MACOSX`, files < 0.03 s.
2. **Slice** (`slice.py`): split multi-take files into takes by an RMS-envelope gate: 10 ms hop, gate at max(−50 dBFS,
   peak − 45 dB), a take starts at the first frame above the gate and ends after 120 ms continuously below it (keep the
   tail down to −60 dB or 4 s, whichever first); ignore takes < 40 ms; one-take files yield one take. Take id =
   `<file sha256[:12]>#<n>` with start/end seconds.
3. **Features** (`features.py`, per take): duration, peak dBFS, integrated LUFS (pyloudnorm; for < 0.4 s use short
   RMS), attack time (−20 dB→peak), decay time (peak→−30 dB), spectral centroid (Hz, mean over the take), low-band
   ratio (< 200 Hz energy share), high-band ratio (> 5 kHz), tonality (spectral flatness inverse), and a 64-point
   envelope. Output `features.jsonl`, one line per take, with the source path and licence id. Must process the whole
   ~1,800-file tree in reasonable time on 4 workers.
4. **Query helper** (`index.py query ...`): filter takes by path substring/regex, duration range, centroid range,
   low-band ratio, attack/decay ranges, LUFS range; print a compact table sorted by a chosen key. This is how the
   director shortlists.
5. **Audition page** (`audition.py --picks picks.json --out <dir>`): for each cue in a picks file
   (`{"cue_id": {"note": "...", "candidates": [{"take": "<take id>", "label": "A", "gain_db": 0, "trim": [s, e]?, "pitch": 1.0?}]}}`),
   render each candidate to a 48 kHz mono-or-stereo MP3 (q 4) normalised to −20 LUFS (short sounds: −14 dBFS peak),
   with 30 ms fade-out; write `index.html` (self-contained: inline CSS/JS, relative `audio/<cue>/<label>.mp3`,
   a play button per candidate, keyboard shortcuts, the cue note, each candidate's source path, licence and key
   features, and a radio choice per cue whose selection is exported as JSON via a "Copy picks" button). Page must work
   offline and as a published static page.
6. **Build** (`build.py --approved approved.json --out-dir assets/audio/sfx/cues --manifest spec/assets/sfx/manifest.json`):
   approved format `{"cue_id": {"category": "impact|body|vocal|ui|card|ambience|spell|movement|status|pickup|stinger",
   "variants": [{"take": "<id>", "trim": [s, e]?, "gain_db": 0?, "pitch": 1.0?, "lowpass_hz": null?, "fade_out_ms": 30?}],
   "loop": false}}`. Render each variant to `assets/audio/sfx/cues/<cue_id>/<cue_id>_<nn>.ogg` (Vorbis q6, 48 kHz;
   mono unless the source is meaningfully stereo — keep stereo for ambience/stingers), loudness-normalised by
   category targets (integrated LUFS; short one-shots use peak targets): impact −16 LUFS / −3 dBFS peak cap, body −18,
   vocal −20, ui −26 (peak −12 dBFS), card −24, ambience −30 (loops: seamless crossfade loop point, 0.5 s), spell −18,
   movement −28, status −22, pickup −22, stinger −16. Write a manifest with every output's source path, take
   start/end, licence id, source sha256, output sha256, and processing parameters. Deterministic bytes (fix encoder
   seed/options).
7. **Docs.** spec/sfx_pipeline.md: how to index, query, audition, approve and build; the licence rules (Sonniss: no
   redistribution as SFX, no AI training; CC0 sources; Mixkit excluded).

## Proof
- `tests/test_sfx_lab.py` with synthetic fixtures generated at test time (sines, noise bursts, silence): slicing
  boundaries, features sanity (centroid of a 1 kHz sine ≈ 1 kHz, etc.), audition page generation for a 2-cue picks
  file, build determinism and loudness within ±0.5 LU, manifest completeness, refusal of excluded paths.
- Run index + slice + features over the real sources into `/private/tmp/labyrinth_codex/sfx_lab/` and report counts
  and timing (the director will re-run it into `output/`).

## Out of scope
- Choosing sounds, game integration, cue wiring.
