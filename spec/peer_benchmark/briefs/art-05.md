# art-05 — Replayable director raw steps in the identity gate (tone, composite, match reference)

## Header
- The rounded gaoler (owner-approved 2026-10-15) was finished with deterministic director steps that the gate does not
  yet know: `spec/art_identity/prototype/tone_region.py` (region Lab tone from a JSON config),
  `spec/art_identity/maquettes/chainbound_gaoler/composite_chain.py` (paste a box from an edit onto the approved raw,
  LANCZOS-resizing a non-1024 edit first), and `spec/art_identity/prototype/mask_reference.py` (a palette-match
  reference with front-only parts made transparent). They are recorded informally in the kits
  (`spec/art_identity/jobs/chainbound_gaoler/mq3_front_v4/kit.json`, `mq3_rear_v3/kit.json`: `tone_edit`, `chain_fix`,
  `match_reference`). rr-02 phase 2 will register the gaoler, so `check` must be able to replay and verify these steps.
- Base: `codex/peer-benchmark`. Owned files: `tools/art_identity_gate.py`, `tests/test_art_identity_gate.py`,
  `spec/visual_identity_gate.md` (Commands/format), the two prototype scripts and `composite_chain.py` (move/port them
  into the gate as library functions; keep thin CLI wrappers so recorded commands still work), and the gaoler job kits
  above (re-record in the new format only — the resulting pixels must be byte-identical).
- Rules: deterministic and byte-identical to the current scripts on the gaoler inputs; no art changes; standard and
  maquette kits keep every existing check.

## Change
1. **`raw_steps`** in a kit: an ordered list applied to the raw before `process`, each step recorded with its kind,
   inputs (paths + sha256 of every input file, including edit images and JSON configs), parameters, and the output raw's
   sha256: kinds `composite_region` (approved raw + edit image + box; edit resized with LANCZOS to the approved size when
   sizes differ) and `tone_region` (config regions as today). `process --raw-steps <kit>` (or reading them from the kit)
   reproduces the final raw and then processes as today.
2. **`match_reference`** for `--match-front`: either a processed front, or a derived reference `{derived_from,
   mask_config}` built by the gate (mask = transparent pixels per config); recorded with digests in the processed
   sidecar's `palette_match` post-step.
3. **`check`** replays `raw_steps` from recorded inputs when the input files are present (maquette jobs keep their
   inputs in the job folder: copy edit images/configs into `refs/` or a `raw_inputs/` folder in the `mq*` job so they are
   committed) and verifies every digest; fails on any mismatch; missing inputs fail for maquette kits.
4. Re-record the gaoler's final jobs (`mq3_front_v4`, `mq3_rear_v3`) in this format with their inputs committed in
   the job folders, and prove `check`-style replay reproduces their `processed.png` byte-for-byte (the raw paintings
   live in the main checkout's `output/peer-benchmark-2026-10-12/identity_gate/raw/`; copy the ones the steps need into
   the jobs). Do not add registry entries for the gaoler (rr-02 phase 2 does).
5. Tests: replay determinism, digest mismatch failures for each input kind, composite with a resized edit, tone with hue
   wrap (lo > hi), mask reference derivation, byte-identity with the old scripts on fixtures.

## Proof
Gate tests; `art_identity_gate.py check` (unchanged result for the existing registry); a replay command for both
gaoler jobs printing matching digests. No windowed runs.

## Out of scope
Registering the gaoler, new art, rr-02's tooling.
