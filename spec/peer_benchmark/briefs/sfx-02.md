# sfx-02 — Sound lab: layered designs rendered from director recipes

## Header
- Goal: the owner rejected every single-take candidate for five cues (block.break, push.slide, trap.trigger,
  radiance.light, illusion.break). Professional game SFX are layered. This unit adds a deterministic renderer that
  turns director-authored layer recipes into designed source files the existing index → features → audition → build
  pipeline treats like any other source. Tooling only: the director writes every recipe (all taste lives there).
- Base: `codex/peer-benchmark` (director gives the commit).
- Owned files: new `tools/sfx_lab/design.py`; modify `tools/sfx_lab/common.py` (designed-source licence rule, shared
  helpers only), `tools/sfx_lab/index.py` (repeatable `--sources`), `tests/test_sfx_lab.py` (new design tests),
  `spec/sfx_pipeline.md` (new section "Layered designs"), `tools/sfx_lab/README.md` (one table row + one paragraph).
- Rules: no network, no package installs, never modify source roots, Mixkit/excluded paths rejected inside recipes
  exactly as elsewhere, ≤ 4 FFmpeg processes with `-threads 2` (reuse the existing slot locks), deterministic output.
- Contract: risk tier low (local tooling, no game files). Acceptance: (1) recipes render byte-identically twice;
  (2) designed files index/slice/feature/audition/build like any source; (3) licence derivation is correct;
  (4) existing sfx_lab tests unchanged and green.

## Recipe format (director-authored JSON; read every value from it)
```json
{
  "<cue_id>": {
    "<label A-D>": {
      "note": "<free text, carried to the sidecar>",
      "length_s": 1.2,
      "master": {"highpass_hz": null, "lowpass_hz": null, "peak_dbfs": -1.0, "fade_out_ms": 30},
      "layers": [
        {"take": "<take_id>", "source_path": "<optional, required when the id is ambiguous>",
         "trim": [0.0, 0.45], "pitch": 1.0, "reverse": false, "gain_db": 0.0, "offset_ms": 0,
         "highpass_hz": null, "lowpass_hz": null, "fade_in_ms": 3, "fade_out_ms": 30}
      ]
    }
  }
}
```
- Every layer key except `take` is optional with the defaults shown. `trim` is seconds relative to the take start
  (before pitch); `null` end = the take end. `master` keys are optional with the defaults shown; `length_s` optional
  (default: end of the last layer).

## Change (numbered, testable)
1. **Layer render** (in this order): decode the take span at 48 kHz float (reuse the existing decode/take helpers);
   trim; tape-style pitch resample (existing helper); optional reverse; optional 2nd-order Butterworth highpass then
   lowpass (`sosfilt`, causal, like build); linear fade-in `fade_in_ms`; equal-power fade-out `fade_out_ms`; gain;
   place at `offset_ms` (sample-exact: round(offset_ms × 48)).
2. **Mix**: sum layers. If any layer is stereo after the existing channel policy, the mix is stereo and mono layers
   are duplicated to both channels; otherwise mono. Master: highpass/lowpass, scale so the absolute peak equals
   `master.peak_dbfs` (never clip; a silent mix is an error), equal-power fade-out over the last `fade_out_ms`,
   truncate to `length_s`.
3. **Output**: `<out-root>/designed/<cue_id>/<label>.wav` (48 kHz, 24-bit PCM, no timestamps or variable metadata)
   plus `<label>.json` sidecar: the recipe entry verbatim, per-layer resolved `source_path`, source sha256, take id,
   take start/end seconds, licence ID, and the derived licence. Write `<out-root>/designed/LICENSE.txt` stating that
   each designed file is a derivative of approved sources and carries the most restrictive licence of its layers
   (the sidecar is authoritative per file). Re-rendering replaces files atomically; files for recipes no longer
   present are left alone (no deletions).
4. **Licence derivation**: any layer from `sonniss_gdc` → `Sonniss GDC Bundle licence`; else `CC0-1.0`.
   `common.py` recognises the `designed` folder as an approved source folder whose per-file licence is read from its
   sidecar (missing/invalid sidecar → rejected before indexing).
5. **Index**: `index.py --sources` becomes repeatable (existing single-root usage unchanged, output order stable:
   roots in argument order, then the existing sort). `audition.py`/`build.py` `--sources` relocation keeps working
   for both roots.
6. **CLI**: `python tools/sfx_lab/design.py --recipes R.json --features F.jsonl --out-root DIR [--only <cue_id> ...]`
   prints one line per rendered file: cue, label, duration, peak dBFS, licence, sha256.
7. **Docs**: spec section with the format, processing order, licence rule and the exact command sequence:
   design → index (both roots) → slice → features → audition.

## Proof
- Python tests with synthetic fixtures (temporary dirs): offsets are sample-exact; reverse and filters apply; peak
  equals the target within 0.05 dB; mono+stereo layers mix to stereo; byte-identical re-render; licence derivation
  (CC0-only vs any Sonniss layer); Mixkit/excluded path inside a recipe is rejected; missing sidecar rejected at
  index; designed files flow through slice/features/audition/build end to end.
- Keep green: all existing `tests/test_sfx_lab.py` cases.
- Report the real-library smoke run: render the director's `R.json` if present at
  `/private/tmp/labyrinth_codex/sfx_lab/recipes_r2.json` (otherwise a two-layer recipe from two CC0 takes you pick —
  a debug fixture, list it under Chosen defaults) into `/private/tmp/labyrinth_codex/sfx_lab/designed_smoke/`.

## Out of scope
- Choosing takes or writing production recipes, audition page changes, game wiring, time-stretch/convolution reverb.
