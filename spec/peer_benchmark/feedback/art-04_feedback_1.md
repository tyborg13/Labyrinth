# art-04 feedback 1 (director)

Renderer proof reviewed: the shrike reads well at board scale in all four facings and the lineup; the density rule's
`regrid` at grid 1.33 is accepted (art_scale 0.75 makes it the finest-grained sprite; the regrid matches the hero's
density). Keep everything you did. Do not commit.

Director data change already made in this worktree (protected; do not edit): each maquette job now stores its
references in the repo, like standard kits — `spec/art_identity/jobs/gust_shrike/mq2_{front,rear}/refs/NN_<id>.png` —
and `kit.json` has `"kit_kind": "maquette"`, `"prompt_path": "prompt.md"` (a byte-identical job-local copy of the
maquette prompt; `prompt_source` names the original), and each ref has `file` (job-relative), `pixel_sha256`,
`role` ∈ {`maquette_parts`, `maquette_clay`, `identity`, `canon`, `edit_source`} and `source_file` (where it was
generated from, informational). The registry's two shrike `prompt_path`s now point at the job-local prompt.md.

1. **Gate support for maquette kits** (`tools/art_identity_gate.py`, tests, and `spec/visual_identity_gate.md` §7b
   Commands/format): for kits with `kit_kind: "maquette"`:
   - job id: require kit `job_id` non-empty and equal to the registry entry's `job_id` (no `id-<id>-<view>` pattern).
   - refs: every ref has a `role` from the set above; its `file` is job-relative under `refs/`, exists, and its decoded
     pixel digest equals `pixel_sha256`. `canon` refs must resolve to a canon id (active or retired; any view — they
     are hand references). Non-`canon` refs must not reuse a canon id. At least one `maquette_parts` ref is required;
     a rear additionally needs at least one `identity` ref. The standard-kit "matching-view canon" and "rear requires
     unchanged first front reference" rules do not apply to maquette kits.
   - kit_version: unchanged rule (prompt bytes + ordered ref digests); verify it reproduces for both shrike kits.
   - Everything else (prompt digest, processed sidecar, post_steps, source/pixel digests, landmarks, judge, approval)
     stays exactly as strict as for standard kits.
   - Tests: a valid maquette kit passes; failures for a ref outside `refs/`, a missing/unknown role, a `canon` role with
     an unknown id, a non-canon ref using a canon id, a digest mismatch, a job id mismatch, a rear without `identity`.
   Then `art_identity_gate.py check` must be `PASS (0 failures, 0 pending_reart warnings)` and the gate tests green.
2. **en05 sync test**: revert your edit to `tests/en05_integration_sync_test.gd` unless it is required by the shrike
   art change; report whether that test fails identically on `codex/peer-benchmark` without art-04 (it is not in the
   full suite?), and leave a pre-existing failure untouched.

Proof: gate tests, gate check, density `--check`, `test_static_facing_assets`, `test_en05_assets`, static facing test,
en05 suite, full suite. No windowed runs are needed (the director already captured the probes).
