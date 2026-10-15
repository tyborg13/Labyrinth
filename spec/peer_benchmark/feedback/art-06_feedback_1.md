# art-06 — round 1 (director): migrate the two lancer v3 kits

Your work is committed (d3e7bb82c) and I merged `codex/peer-benchmark` into this branch (bbfcb2a73). The merge brought
two new raw_steps kits written with the art-05 field names after you branched:

- `spec/art_identity/jobs/frostglass_lancer/mq1_front_v3` (one tone_region step; front)
- `spec/art_identity/jobs/frostglass_lancer/mq1_rear_v3` (one tone_region step; `match_reference` is a plain processed-front
  binding to `refs/palette_front.png`, a byte copy of `mq1_front_v3/processed.png`)

1. Re-record both with the art-06 format exactly as you did the other three: pixel digests for outputs, and the rear's
   match reference bound to the front **job** `mq1_front_v3` (job path + processed pixel digest) instead of the copied
   PNG; delete `mq1_rear_v3/refs/palette_front.png`. If the job-link form currently exists only for `derived_from`,
   extend it to the plain processed-front case (same validation: fails when the front job's processed pixels change).
   Pixels must stay identical (processed PNGs unchanged).
2. Add a small helper so the director never hand-computes these again: `tools/art_identity_gate.py record-steps
   --kit JOB/kit.json` that recomputes and writes every `output_raw_pixel_sha256`, input file sha256 and the
   match-reference job digest for a kit whose steps/inputs are already listed, printing what changed; refuses when an
   input file is missing. Use it for item 1, and document it in `spec/visual_identity_gate.md` (repo-relative).
3. Update the doc sentence that says art-06 re-records "only the three existing recipes" to list all five.

Proof: gate tests, `check` PASS (0 failures), replay PASS for all five raw_steps kits, a test for `record-steps`.
Do not commit; do not merge.
