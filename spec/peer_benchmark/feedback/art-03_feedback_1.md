# art-03 feedback 1 (director)

Facing, portraits, density and the new gate steps look right; decisions for the open items:

1. **TODO_DESIGN_APPROVED_KIT_REFS**: reference PNGs are git-ignored on purpose (regenerable from canon). `check` must
   not require the files: verify a kit entry against its job's committed `kit.json` and `prompt.md` (prompt sha256 and
   the recorded ref pixel digests), never against ref files on disk.
2. **TODO_DESIGN_APPROVED_KIT_VERSION**: `kit_version` is provenance at generation time. Recompute it from the job's own
   committed inputs (the stored `prompt.md` bytes, the recorded view-clause/preamble text as captured in that prompt,
   and the recorded ref digests in `kit.json`), not from today's `preamble.md`/`views.md`, which have legitimately
   evolved since. If the stored inputs cannot reproduce the recorded value exactly, verify `prompt_sha256` against
   `prompt.md` and treat `kit_version` as a recorded field (document which).
3. **TODO_DESIGN_GLACIAL_MIRROR_REAR_CONSISTENCY**: measure rear consistency over non-accent pixels only (the same
   accent mask as the palette-match step: chroma > p90 + 15), so a front-only accent (the mirror plate) does not count.
   Keep the 0.03 bands.
4. **en01–en06 suites**: the director updated `spec/peer_benchmark/staged/enemies/wave_e1.json` / `wave_e2.json` with
   the new `art_scale` / `art_rear_path` (uncommitted in this worktree — keep them). Re-run; they should pass.
5. **Density test**: `tests/test_board_pixel_density.py` hard-codes the old Storm Capacitor scale
   (`216 * 1.2 / 243`); the art changed intentionally — use the data `art_scale` like every other enemy.
6. Fix the remaining gate test failure (root-cause it and state it).

## Proof
Full suite green, `check` green except gust_shrike pending, density/icon/gate tests green; list the two windowed probe
commands again.
