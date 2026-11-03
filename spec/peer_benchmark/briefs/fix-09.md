# fix-09 — Test coverage after the last static enemies became cutouts (rr-32/rr-33 fallout)

## Header
- Base: `codex/peer-benchmark` (rr-32, rr-33 and el-02 merged). Risk tier: low. Tests and one call-site restructure only.
- Owned: `tests/sfx_sync_*.gd`, `tests/sfx_sync_test.py`, `tests/fixtures/*sfx*`, `tests/perf/*`, and the single
  enemy-phase push line in `scripts/run_scene.gd` named below.
- The approved SFX baseline `spec/peer_benchmark/staged/sfx/sync_baseline.json` stays byte-for-byte unchanged.

## Why
Full Godot suite on integration 0027e90ee:
- `suites/sfx_sync_0/1/2_program` FAIL with two errors each:
  - `Cue × call-site coverage shrank: push.slide|scripts/run_scene.gd|_animate_enemy_phase_steps|if str(step.get("kind", "")) in ["push", "pull"]: _sfx_router.push()`.
    rr-32 (b7ed75103) appended `and MaquetteAction.contact_cue_for(step, dragon_actor) != "push.slide"` to that line, so
    the baseline site identity (file|function|code) no longer exists.
  - `Uncovered live call site: scripts/maquette_cutout_runtime/contact_actions.gd|animate|if not cue.is_empty(): scene._sfx_router.request(cue)`.
    rr-32 added cutout contact-frame cues; no SFX scenario plays one.
- `perf/combat_frame_scenarios` FAIL: `tests/perf/hover_equivalence.gd:_catalog` requires a live enemy with a
  directional still (`Fixture includes a directional still`), then crashes at line 138. The Gale Herald and Gloam Stalker
  were the last such enemies; every enemy is now a cutout.

## Change
1. **Keep the baseline site identity.** Restructure `_animate_enemy_phase_steps` so the original line
   `if str(step.get("kind", "")) in ["push", "pull"]: _sfx_router.push()` is byte-identical again. Put it inside an
   enclosing guard that skips it when the step's maquette contact cue is `push.slide`. Behaviour is unchanged.
2. **Cover cutout contact cues.**
   - Add an additive SFX scenario, the same way `tests/fixtures/empower_sfx_samples.json` is merged: a Gale Herald
     `gust_bolt` whose push contact plays `push.slide` through `contact_actions.gd`.
   - Assert that it plays exactly once, on the contact frame (not twice through the generic push path).
   - The new site and its cue × site pair are covered; every baseline pair still recurs.
3. **No live directional still is required.**
   - `hover_equivalence._catalog` (and any other test that assumes one) keeps its directional-still mutation coverage
     through a synthetic, test-only enemy definition injected into the catalog and restored afterwards.
   - Don't add art or data entries to production files.

## Proof
- The three `sfx_sync` programs PASS, `tests/sfx_sync_test.py` OK, `perf/combat_frame_scenarios` PASS.
- Registration audit OK.
- Mutations:
  - Revert the guard so push.slide plays twice: caught.
  - Delete the contact-cue scenario: the coverage check fails.
  - Remove the synthetic still: caught.
- Focused only.

## Out of scope
Any change to SFX timing, cue data, the approved baseline or the static-facing runtime.
