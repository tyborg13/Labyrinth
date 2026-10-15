# art-06 — Identity gate robustness follow-ups (art-05 review)

## Header
- art-05 (merged 2eb5b4d17) made director raw steps replayable. Its peer review (signoff with follow-ups) found that
  `check` depends on the local PNG encoder: `output_raw_sha256` (via `png_bytes`), the derived `reference_sha256` and the
  `processed.png` byte comparison all hash bytes re-encoded by the local Pillow/zlib build, so a different build turns
  `check` red with identical pixels — that will include the registry once rr-02 registers the gaoler.
- Base: `codex/peer-benchmark`. Owned files: `tools/art_identity_gate.py`, `tests/test_art_identity_gate.py`,
  `spec/visual_identity_gate.md`, and the existing raw_steps kits (`spec/art_identity/jobs/chainbound_gaoler/mq3_front_v4`,
  `mq3_rear_v3`, `spec/art_identity/jobs/frostglass_lancer/mq1_front_v2`) — re-recorded only, pixels unchanged.

## Change
1. **Pixel digests for chained/derived images**: every recorded digest of an image produced by the gate (raw-step outputs,
   derived match references, processed sprites) is a decoded-pixel digest (`pixel_digest`, RGBA bytes + size); byte
   equality of re-encoded PNGs becomes a diagnostic only. Input files supplied by the director (raws, edits, configs) keep
   file sha256 bindings. Migrate existing kits (field rename, e.g. `output_raw_pixel_sha256`) with a one-time re-record;
   `check` accepts only the new fields afterwards.
2. `validate_kit_entry` reports a skipped replay ("SKIP raw_steps replay: inputs absent") as a WARN line in the report
   instead of discarding it; an exception inside `verify_job_recipe` is reported per entry without dropping that entry's
   other failures.
3. **Dedupe committed inputs**: replay may use the previous step's in-memory output, so intermediate raw files need not be
   committed; remove redundant copies (`mq3_rear_v3/refs/palette_front.png` duplicating a processed front, the
   unreferenced `mq3_front_v4/match_reference_no_tabard.png`, intermediates) while keeping every first input and config.
4. **Front link for rears**: a rear's derived match reference records the front **job** it derives from (path + pixel
   digest of that job's `processed.png`); `check` fails if the front job's processed sprite changed since.
5. Docs: repo-relative commands in `spec/visual_identity_gate.md` (no absolute worktree paths); a legacy direct
   `--match-front PNG` must be repo-relative and, for maquette kits, inside the job folder.
6. Tests for the art-05 review's surviving mutants: the maquette `refs/`/`raw_inputs/` rule with an existing file, the
   `--match-front` vs kit conflict, extra composite parameters, box bounds, and the reference/final-raw/kit-reference
   guards when standard-kit inputs are absent.

## Proof
Gate tests; `check` output unchanged in substance (PASS, 0 failures); replay of the three raw_steps kits; a test that
re-encodes a processed PNG with different zlib settings and still passes `check`.

## Out of scope
Registering the gaoler (rr-02 phase 3), new art.
