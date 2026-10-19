# rr-18 — Glacial Mirror humanoid v2 implementation

Changes remain uncommitted on `codex/rr-18`. This implementation preserves the director's mq8 paintings, mq-08 delivery and motion-track bytes. No art/audio/font/icon generation, maquette edit, combat tuning, analytics/save change, peer review or publication was performed. The unit brief assigns full suites, native inspection, commits and publication to the design owner.

The implementation is **not acceptance-complete**: the unchanged geometry and protected walk keys fail the strict knee/support gates, and mandatory density processing conflicts with the zero-pixel production-rest requirement. Four explicit design TODOs are retained in `rr18/inputs.json`, `rr18/cutout.json` and production `integration.json`. No failing gate was relaxed.

## Numbered acceptance criteria

1. **Rigid cut and registration.** Fifteen rigid boulders per view use the specified labels/bones, including `hand_*` → `fist_*`. Each has its own hidden continuation, with the spec's minimum 3 px tuck under its adjacent boulder. Both hands and both visible feet use the existing two-bone solves. Case anatomy declares each leg's per-view rest bend side and the Thrall's stride/trailing roles. The source-only partition reconstructs both approved paintings at **0 px mismatch**. The sole front feature is torso-owned `ice_mirror`; its proof mask protects the entire owning chest boulder, including the inset. Two one-pixel categorical islands transfer intact to their four-neighbour owner under the existing workflow cleanup rule; exact coordinates/provenance are in `rr18/ownership/`. All visible pieces are single connected components. **Facing-knee acceptance is unresolved**, as described below.
2. **Idle.** Torso, head and both free arms form the upper group. Pelvis, legs and feet remain stationary. The weapon group has no painted members; `root` is its stationary proof anchor. This preserves the existing three-group schema/probe contract without inventing a weapon or a second arm bob. The protected 0.84 s / 2 px idle uses the existing 10 fps whole-pixel presentation. All headless idle bases/group offsets pass; native isolated-pixel proof is pending.
3. **Production.** Registration routes board, per-tile advance, pre-battle and live portrait consumers to the production-owned two-view closure. Source-derived floor/HUD records are in `scripts/actor_presentation.gd`. `advance:move_toward`, `refraction:aoe`, `crystal_guard:guard_ally`, hit and death route to `move`, `refraction`, `guard`, `hit`, `death`. Existing reaction/death/fade handling is reused through the family registration, with Mirror removed from the static roster. A case-owned contact adapter normalizes the resolver's `action_type: refraction` solely for clip selection; wards animate `source_actor_key` while the untouched recipient-addressed step still owns the outcome/VFX. Existing Refraction beam duration and sound entries, ward feedback and block sound run once at the protected contact, including reduced motion. Actual RunScene callbacks are checked in both production views, with an ally in the corresponding facing for guard.
4. **Case data.** No `humanoid_*.gd` or `tools/humanoid_cutout/**` changes. The only new generic facility is the optional `ACTION_ADAPTERS` registration/lookup in `presentation.gd` and six lines of source-actor-aware dispatch in RunScene. Existing Seer/Thrall dispatch is unchanged. Other shared edits are Mirror-only roster/family, asset-directory, floor/HUD and static-facing registrations. Production contains its own paint/layouts/director copy/compiled data and adapters, without an authoring-case dependency.
5. **Gates.** Shared source/cut, idle/signed Bone2D, required action-direction coverage, and dense reach (1,000 intervals plus interval minimum) pass in both views. Twelve keyed reach paths per view report overreach (front four, rear three) without failing. The case adds strict treated-production rest identity checks and checks for **both** move swings and both feet's stationary supports in move/refraction/guard/hit. These report the supplied walk conflicts and the density/rest-identity conflict. Native rigid-sprite, calibrated seam-hole, stray-pixel and isolated idle RGBA checks are wired through the rr-11 renderer probe and shared gates. Its headless validation loads every piece/mask; no native pixels are claimed. The separate treated-production rest check fails; source cut equality alone does not certify it.

## Unresolved design data

- `TODO_DESIGN_near_knee_facing`: mq8 near knees bend opposite facing at rest: **8.998° front, 9.537° rear**, beyond the inherited 6° near-straight threshold. The solver refuses a policy contradicting those rest sides. The implementation preserves the actual rest bend side, which is the closest supported interpretation, and keeps the facing gate strict.
- `TODO_DESIGN_move_swing_apex`: front stride apex is **30.218° swing versus 62.233° stance**; rear trailing apex is **4.542° swing versus 29.019° stance**. The ≥15° *peak* condition passes every swing, but the apex comparison fails those two swings.
- `TODO_DESIGN_density_rest_identity`: mandatory density processing changes **1,178 front / 15,491 rear pixels** in the actual production rest assembly. Front uses derived `clean` mode, rear `regrid` at 1.22. The authoring cut stays exact. The brief and required density pipeline conflict; the implementation retains the existing pipeline and explicitly fails production rest identity rather than inventing an unapproved density override. A separate strict source-space production-rest gate and mutation regression cover this.
- `TODO_DESIGN_move_supports`: the protected world-step walk exceeds the unchanged leg reach at the reference 96 screen-px / 2× proof scale. Maximum floor-target errors are **5.545222 px front** and **19.416488 px rear**; maximum presented stance slide is **1.414214 px**. Refraction/guard/hit supports pass. The tracks explicitly world-plant both feet, including the short trailing leg; they are preserved verbatim.

`rr18/proof/{gates,knees,supports,reach,directions,production_rest}.json` retain the measurements. The combined strict gate currently exits 1 with **100 unique errors**: 98 walk knee/support diagnostics and two treated production rest mismatches. Fixing these requires the director to resolve the protected input conflict. Runtime readiness remains false.

## Files changed

- `experiments/cutouts/glacial_mirror/`: case anatomy/inputs, protected import, compiled tracks, registered baseline/source provenance, cut pieces/continuations, tucks/features/seams/check masks, source-only build, cleanup, gates, mutations, density registration, focused runner and proof launcher.
- `assets/units/glacial_mirror_cutout/`: production rigid closure, `rig.gd`, `renderer.gd`, `actions.gd`, density-facing layouts and pending integration record.
- Mirror records in `scripts/{actor_presentation,combat_board_view,cutout_context,static_enemy_facing}.gd`, optional registration in `scripts/maquette_cutout_runtime/presentation.gd`, dispatch in `scripts/run_scene.gd`.
- Mirror-only entries/sources in `spec/assets/board_pixel_density/{registry,outputs}.json`, `sources/assets/units/glacial_mirror_cutout/`; Mirror rest identities in `spec/art_identity/registry.json`; Mirror rest shadow records in `assets/generated/unit_shadow_cache.res`.
- `tests/rr18/`, `tests/test_rr18_humanoid.py`, and one headless-program registration in `tests/headless_test_programs.json`.

The preservation audit compares **3,616 tracked files** against Git blob hashes, including Seer/Thrall cases/assets, generic humanoid modules and protected Mirror inputs. Other-unit identity/density records remain identical. The shadow refresher asserts all unrelated resource entries remain equal. Fresh regression rows compare 990 Thrall and 1,258 Seer poses exactly. This is headless render-input/pose evidence, not a new native pixel comparison.

## Headless reproduction

Run from this worktree. The initializer/build import the protected director file without editing it. Rebuilding case-owned derived paint requires explicit source readoption:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_case.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_build.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_density.py --refresh-sources
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 tools/godot_task_runner.py --task-id rr-18 --stream -- godot --headless --path . --import
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_focused.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_mutations.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 tools/godot_task_runner.py --task-id rr-18 --stream -- godot --headless --path . --script tests/rr18/action_direction.gd -- --case experiments/cutouts/glacial_mirror/rr18 --output experiments/cutouts/glacial_mirror/rr18/proof/samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_gates.py
```

The last command must currently fail; it is not waived. The import command bootstraps resource sidecars; actual runtime checks and samplers supply parser/runtime proof. The focused runner includes only rr-10/11/14/15/16, rr-07 production, registration-audit regressions and rr-18 tests, remapping historical task-runner IDs to rr-18 without altering assertions. The full Python and Godot suites were not run, per the unit brief.

Final exact result lines, remaining commands and per-command logs are recorded in `rr18/proof/verification.json`. Logs are under `/private/tmp/labyrinth_codex/rr18-*.log`. Source-cut inspection sheets are ignored `rr18/proof/source_cuts_{front,rear}.png`; they contain approved-source extraction, not renderer captures.

## Proof for the design owner

No windowed command was attempted. Run the following at 1920×1080 / 100% UI scale after resolving the design TODOs. The wrapper invokes `tools/visual_probe_runner.py` and the explicit JSON contracts; it never retries GUI backends. `production` captures front and rear in separate processes and checks actual shown facing. The native stage retains the strict knee/support gate and will fail until the director resolves the source conflict.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh review
```

Captures stay ignored under `rr18/proof/{native_rest,native,contact_sheets,idle_native,production_native}` and `*.mp4`. Density processing/adoption is complete; **native rest records remain pending**. The prepared shadow entries currently derive from the identical approved-source rest, and the density stage refreshes them after the native rebake. No `inspection_fixture.py` command is requested by this brief; fixture preparation belongs to the design owner.

## Chosen defaults

Only proof/test values were chosen; no player-visible tuning was invented. Named values are in `tests/rr18/` and `tests/test_rr18_humanoid.py`: the reference sampler's `PROOF_STEP_PX=96`, `PROOF_SCALE=2`, source origin `(128,128)` and 512px pose canvas; inherited native proof camera/caption fields, six representative frames, five idle loops; `PROOF_IDLE_SEED=.37`, `PROOF_IDLE_SAMPLES=51`; fixture actor `(2,4)`, production ally/contact `(3,4)`, runtime-test ally `(2,3)`, reflection x sum `8`, target `(4,4)`, hit HP `30`, RGB mutation XOR mask `1`, eight settle frames, seed `91210`; mutation frame `5`, slide `1px`, rotation-basis perturbation `.1`, 180s headless process budget. Source-only sheet diagnostics use five columns of 255px cells, recorded in ignored `proof/source_review.json`. The empty weapon group's stationary root anchor is diagnostic membership only. The component-cleanup threshold, knee/support tolerances and motion/presentation numbers come from the existing binding workflow/specification.

## Open issues

The four design TODOs and unperformed native proof are the remaining acceptance blockers. The first focused run had one error in the new empty-native-manifest test, which expected a returned failure list where the established API raises `CutoutError`; that new assertion was corrected, and the final 184-test focused set passed, including the new treated-production identity regression. Exact counts are in `rr18/proof/verification.json`. The first production run exposed existing resolver spellings/source ownership; the case adapter fixes were verified in subsequent callback runs. No master assertion was rewritten.
