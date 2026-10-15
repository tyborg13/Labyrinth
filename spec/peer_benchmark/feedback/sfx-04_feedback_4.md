# sfx-04 — round 4 (peer review of 6eca206c0: CHANGES REQUESTED; director rulings included)

Work on top of 6eca206c0. Do not commit.

## Blocking
1. **Combat speed** (Fast 1.5×, Fastest 2× via `Engine.time_scale`): climaxes are authored in visual time but audio runs
   in wall time, so at 2× roar peaks land +165…+298 ms late and blink/cast.arcane fail again (the owner's original
   complaint). Convert every climax to wall time with the effective scale (`_combat_pacing.current_scale()` or
   `Engine.time_scale`) before planning; route ordinary `move.blink` (blink, relay, illusion_swap) and `cast.arcane`
   through per-call alignment with their observed climax instead of relying on the 1× baked trim. Delays respect pause
   and hit-stop (never fire early after a pause). Harness: run every scenario at 1×, 1.5× and 2×.
2. **`shop.sell_02.ogg` is malformed** (Godot reports 89478.8 s; bad end-of-stream granule). Re-encode/remux it; add a
   check over every changed file that Godot's reported length equals the decoded length (±1 ms).
3. **Peak policy**: the loudness-restore gain must respect the build's caps: never above the category target (−3 dBFS for
   impacts) and never above −1 dBTP. Six impacts and card.exhaust currently exceed them (hit.pierce −0.02 dBFS,
   +0.09 dBTP). Under the cap, loudness may fall up to −1.0 LU (rise ≤ +0.5 LU); list any file outside that window.
4. **Tests in the suite**: add `sfx_sync_bank_test.gd` to `program_sub_suites.gd` SUITES; assert |peak − climax − 15| ≤ 1 ms
   for aligned rows; drive `bank.play(cue, {"peak_climax_ms": …})` at forced pitch bounds (catch "plan at pitch 1.0");
   guard `_peak_pending` before indexing (no crash/hang).

## Director ruling: keep the first transient
5. Aligning to the single strongest envelope peak cut away earlier transients that were nearly as loud (spell.lightning
   cut 1 ms after its old peak; 17 files lost content within 1 dB of the old peak). New rule: the alignment peak is the
   **earliest local maximum within 2 dB of the strongest peak**, and the cut point must sit at least **20 dB below** that
   peak (move the cut earlier until it does; still ≥ 15 ms before the peak, 3 ms fade). Re-trim from the lossless sources;
   report every file whose trim changed, and put the 17 + 15 flagged files on the listening checklist.

## Lower severity (do these too)
6. Coverage identity = file + function + normalized statement (no neighbouring lines), so innocent nearby edits don't
   fail the suite.
7. Same-frame collapse: one voice per **distinct cue** per frame (a blocked and an unblocked hit on the same frame both
   play, at −6 dB layering as now).
8. First-action roar: if an action has a dragon profile but no profiled effect is presented (Umbra-hidden steps,
   special-view steps, effects without `enemy_type`), play the roar at action start as before. Add harness scenarios for
   meteor and utility geometries.
9. Tunables in data: a `rules.sync` block in `data/sfx_cues.json` (target lag 15 ms, minimum kept before peak 15 ms as a
   separate constant, fade 3 ms, window, onset caps, the 2 dB / 20 dB alignment rule) plus a per-cue warm-up flag
   (replacing the hard-coded list); GDScript and Python read the same values.
10. **Repo hygiene**:
    - Replace the 3.7 MB `sync_audit.json` with a compact `sync_baseline.json` (≈60 KB: per-sample metrics with sha256,
      cue × call-site identities, observation counts, silent-visual rows, area loudness, summary — what
      `sfx_sync_coverage.gd` reads) plus the markdown (policy, current table, listening checklist, follow-ups).
    - Compact provenance (hashes, removed samples, fade, gain, constraints, before/after metrics; recipe via the parent
      manifest sha256; toolchain versions). The rebuild reads per-path constraints from provenance, not from the
      `feedback_1_before` phase.
    - Full reports regenerate to `output/` (gitignored path) via `tools/sfx_sync_audit.py --report`.
    - No absolute `/Users/...` or machine temp paths anywhere; plain `sync.py` is idempotent.

Proof: harness at 1×/1.5×/2× (all aligned rows within ±1 ms of +15), bank test in the full suite, sound lab, cue
coverage, full Python + Godot suites, the peak/length checks, and the list of re-trimmed files.
