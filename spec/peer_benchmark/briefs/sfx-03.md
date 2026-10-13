# sfx-03 — Lookahead limiter stage for transient-heavy cues

## Header
- Owner (2026-10-12): "the volume is all over the place". After the mix pass three transient-heavy cues stay short of
  their momentary-max loudness targets because their peaks already sit at the −1 dBFS cap: hit.blade.light −25.4 vs
  −19, status.shatter −24.5 vs −19, status.freeze −28.4 vs −24 (measurement: max over 400 ms windows, 100 ms hop, of
  ITU-R BS.1770 integrated loudness — see the director script `spec/peer_benchmark/staged/sfx/measure_mix.py`, add it).
- Director decision (overrides the spec's "no limiter" sentence for these cues only): a per-variant lookahead peak
  limiter stage. The owner-approved takes stay the same; only their level and transient peaks change.
- Owned files: `tools/sfx_lab/build.py` (+ `common.py` if shared), `tests/test_sfx_lab.py`, `spec/sfx_pipeline.md`
  (build section), `spec/peer_benchmark/staged/sfx/approved_v1.json` (add `limiter` to these three variants only),
  `assets/audio/sfx/cues/{hit.blade.light,status.shatter,status.freeze}/*` + their `.import` sidecars, the SFX manifest,
  `data/sfx_cues.json` (`volume_db` of these three only). Venv: `/Users/borgerding/.cache/umbra-sfx/venv/bin/python`.

## Change
1. `limiter` variant field: `{"input_gain_db": G, "ceiling_dbfs": -1.0, "lookahead_ms": 2.0, "release_ms": 60.0}`.
   Stage position: after the fade-out and before normalization. Algorithm: apply G; gain computer = min(1, ceiling /
   |x|) per sample (max over channels); lookahead = sliding-window minimum over `lookahead_ms`; attack follows the
   lookahead ramp (linear over the window), release is one-pole exponential with `release_ms`; output never exceeds the
   ceiling (verify on the float signal and after encoding within the existing tolerance). Record the parameters, max
   gain reduction (dB) and the pre/post peak in the manifest.
2. When a variant has a limiter, normalization is skipped (the limiter ceiling is the level control); the encoded peak
   check uses the ceiling.
3. Values: hit.blade.light G = +7.0 dB; status.shatter G = +6.0 dB; status.freeze G = +5.0 dB.
4. Rebuild only those three cues; then set each cue's `volume_db` = target − measured momentary-max (targets: −19, −19,
   −24), but never so high that encoded peak + volume_db > −1.0 dBFS; report final momentary-max and peak per cue.
5. Spec: replace the "No taste-selected compressor or limiter" sentence with the limiter rule (director-specified per
   variant; transient-heavy cues that cannot reach their target under the peak cap).

## Proof
- Unit tests: ceiling never exceeded; release curve; lookahead attack starts `lookahead_ms` early; determinism; manifest
  fields. sfx bank test; full suite.
- A before/after table (momentary-max, peak, max gain reduction) for the three cues, and short before/after WAV pairs
  under `output/sfx-03/` for the owner to compare.
