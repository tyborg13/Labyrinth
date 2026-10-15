# art-06 — round 2 (peer review of b7d71316f: integrity holds in all 68 scenarios; tests and hardening requested)

Work on top of b7d71316f. Do not commit.

1. **Kill the five surviving mutants** (tests/test_art_identity_gate.py):
   a. maquette `refs/`/`raw_inputs/` rule in `derive_match_reference`'s plain-path branch (`:493`): a maquette kit with
      `match_reference {"path": "processed.png", "pixel_sha256": …}` raises "maquette input must be inside". Better: route
      that branch through the same helper as `recipe_input` so the rule exists once.
   b. registry rejection of `raw_sha256` on raw_steps entries (`:1117`): expect "requires raw_pixel_sha256, not raw_sha256".
   c. post_steps parameter / pre-step digest validation before SKIP (`:849`) and the order check (`:847`): with raw
      removed, a bad `pre_step_pixel_sha256`, changed parameters, and reversed order each fail with their messages.
   d. the `or "raw_steps" in kit` clause (`:861`): no kit match_reference, sidecar palette step with `reference` but no
      digests, raw removed → "reference pixel digest changed".
   e. extra keys on front-job bindings (`:470`): an extra `path` key raises "front requires job_path and pixel_sha256".
2. **`record-steps` is director-only**: one doc sentence (re-binds current file bytes; review every input sha256 change;
   never run by check or CI) and print `INPUT CHANGED <path> old→new` when an existing valid input digest changes
   (distinct from migration lines).
3. **Resolved paths**: the maquette `refs/`/`raw_inputs/` rule checks the resolved path against
   `(job/"refs").resolve()` / `(job/"raw_inputs").resolve()` (a `refs/x.png -> ../copy.png` symlink must fail).
4. **Front-job link scope**: `job_path` must lie under `spec/art_identity/jobs/` and the front kit's `id` must equal the
   rear kit's `id`; a null/missing `view` gives a clean error, not a traceback.
5. Remove dead `png_bytes` (no callers); `record_steps` writes with `write_bytes(... .encode("utf-8"))` (LF).
6. Count `WARN … SKIP` lines in the summary and make `--strict` fail on any skip.
7. Gaoler `mq3_front_v4/refs/palette_front.png` duplicates `chainbound_gaoler/mq_front_v3/processed.png` pixels: replace it
   with a front-job link if the binding form allows it for a front's own reference; otherwise leave it and say why.
8. Doc nit: replace `/tmp/lancer-rear-recording/…` with a placeholder.

Proof: gate tests (report the five mutants caught), registry `check` PASS, `check --kit` PASS for all five raw_steps kits.
