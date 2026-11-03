> Initial implementation record. Current feedback-1 changes, exact final results and remaining acceptance issues are in [rr38_FEEDBACK1.md](rr38_FEEDBACK1.md).

# rr-38 implementation handoff

Work is uncommitted on `codex/rr-38`. No task commit, branch change, publication, queue edit or peer review was performed. Native acceptance is pending.

## Numbered brief requirements

1. The unchanged mq3 paintings are cut against independently registered mq-15 views. Torso owns the cowl; pelvis owns belt/buckle; tabard and both coat tails are pelvis cloth chains; arms/legs have skinned roots and rigid hands/boots. Chain/hook are one rigid held item on hand_far. Front visor and tower features stay with head/tabard. Both source rests reconstruct at 0 px. Production paint/rest is density processed at the existing 0.9 art scale.
2. First-pass fills use their own non-outline texels at least 2 px inside the rest silhouette. The independent uncovered domains and full vacated footprints cover both arms, both legs, fists, boots, chain and cloth. Flat regions have crops; no second procedural fill method was attempted. The missing fills/seams and flat flags remain acceptance failures or director judgments, not exceptions.
3. Camera arm is above all body/cloth in each view; head is above both arms; chain is above the body. Layout and sampled node depths are checked. Native component counts and hook-at-contact occlusion checks are written for the director's captures.
4. Shared production routing replaces the bespoke renderer on board, pre-battle and live portraits. Intent selectors and all timing come from the protected motion copy. Every movement uses move. Press trails use hand_near and exact transform restoration. Real resolver/contact/pose probes pass in both views. Hit/death use the shared v2 recovery/terminal/fade path. The hanging chain's missing drop channel is explicitly deferred below.
5. Per-view, per-leg knee policy comes from certified native joints. Stance bends (near/far): front 15.665069 / 5.388679 degrees; rear 17.399070 / 6.884122 degrees. Walk swings, support, dense minimum reach and policy mutations are checked. Dense overreach is reported (front 5 paths, rear 4), not failed.
6. Source and treated numeric/source gates, fresh authored/presented samples, mutation controls, D1–D5 diagnostics, native UV ties, native draw order/components, rigid chain attachment/release and all windowed proof contracts are implemented. CPU defect results and full-suite failures are retained below. Native 1920x1080 / 100% judgment was not run.

## Shared changes

- `tools/humanoid_cutout/compiler.py`: optional held-item angle_sign, default 1. Gaoler uses -1 so the hanging hook leads positive casts. Existing v2 compilations are unchanged; Capacitor's semantic compilation remains byte-identical.
- `tools/humanoid_cutout/uncovered_surfaces.py`: optional visible_occluders_only, default false. Gaoler excludes hidden receiving paint from the current visible occluder footprint. A constructed missing-fill frame fails.
- `scripts/maquette_cutout_runtime/presentation.gd`: identity registration only. The existing sampler, renderer and rr-40 full Transform2D paths are retained.
- `tests/maquette_cutout/dependency_closure.py`: ignores deleted, unstaged files when deriving the global-class list from Git. Explicit preloads of missing files still fail; a constructed retirement control covers both behaviors. This supports the required uncommitted worktree.
- Old Gaoler renderer/name dispatch is removed. Public Gaoler snapshot/scale accessors remain. Tests and benchmark adapters select the v2 paths.

## Observed proof

See `rr38/proof/verification.json` for commands, exact result lines, complete failure lists and log hashes.

- Focused Python: `Ran 12 tests in 19.092s` / `OK`, with 1348 fresh bone poses; includes constructed missing-fill, constant-donor, foreign-fill, grip and direction controls.
- Source and treated rests: 0 px source ownership mismatch. Native rest seal is pending; `process_board_density.py --check` reports the two missing native rebake records. No record was forged.
- Source sweep: 892 frames; 422 findings (312 frames with missing pixels, 102 with joint tears, 8 with tiny components); 5449 low-texture regions (39 have a constant donor, so no comparative texture can be established). D1=D2=D3=D4=D5=0. Maximum final shard: 29.789 seconds. Full log: `rr38/proof/logs/cpu_sweep.json`. `rr38/proof/cpu_sweep.json`, `flat_fill_summary.json`, and ignored `proof/cpu_frames/` retain all frame reports/crops. These are CPU construction aids.
- Treated sweep: 892 frames; the same 422 findings; 5300 low-texture regions, including 39 constant-donor flags. D1=D2=D3=D4=D5=0. Maximum final shard: 29.735 seconds. Full log: `rr38/proof/production_case/proof/logs/cpu_sweep.json`. `rr38/proof/production_cpu_sweep.json` binds the full ignored log and groups every flagged region by piece/clip/frame with representative crops.
- Production logic: both views pass contact/outcome/pose checks. Full logs: `/private/tmp/rr38-production-front-verified/logic_frames.json` and rear equivalent. Compact hash-bound summary: `rr38/proof/production_logic.json`.
- Package: production-only PCK builds/verifies from an empty project; stock release template reports `GAOLER CUTOUT EXPORT RUNTIME: PASS (editor=false)`. The unmodified executable needs the PCK beside it with a matching basename; no binary was modified.
- Full Godot: `TEST RESULT: FAIL (4 failure(s))`, `FULL SUITE RUNTIME: 806.222 seconds (budget 900 seconds)`. Failures: special_encounter_test (two emblem import assertions); enemy_no_action_test (missing GameData declaration, exit 124); fix_11_test and fix_11_probe (same unchanged missing GameData dependency). These assertions/files were not rewritten. All Gaoler programs, contextual reactions, pose application and SFX programs pass.
- Full Python: `Ran 1969 tests in 4027.597s` / `FAILED (failures=8, errors=4, skipped=66)`. Raw failures: native-rest certification; the superseded silhouette-probe expectation; the supplemental-program suffix guard; five dependency-mutation subtests. Errors: two dependency-closure reads of deleted unstaged scripts; two Weaver review tests missing the ignored output parent. After the integration fixes, the 82-test rerun has only the native-rest failure; the two Weaver checks then pass (`Ran 2 tests in 36.241s` / `OK`). The full Python run was not repeated after these fixes; no all-green full-suite claim is made. Complete canonical test names remain in `verification.json` and the full log.
- SFX sync: PASS, 4243 / 3516 / 1688 observations, zero failures in each program.
- Registration audit: `TEST REGISTRATION AUDIT: PASS (841 scripts; full suite=487, quarantined=29, windowed probe=325)`.
- Art identity: `Ran 111 tests in 49.864s` / `OK`. Icon identity: `Ran 8 tests in 0.075s` / `OK`.
- Integration Python after fixes: `Ran 82 tests in 140.745s` / `FAILED (failures=1)`. The sole remaining failure is `test_board_pixel_density.BoardPixelDensityTest.test_shipped_derivations_and_manifest_are_current`: both Gaoler rests need the director's native rebake. All paint adoption, scale, silhouette, suite-manifest and dependency-closure assertions pass.
- Weaver cold-review checks pass after creating the missing ignored `mq9/proof/logs` directory; their assertions and figure files are unchanged (see verification log).
- Optional legacy CPU benchmark reaches the new Gaoler rig, but the all-figure benchmark reports the unchanged Lightning Wisp `crown` error. Both changed benchmark scripts load headlessly. No performance acceptance is claimed.

## TODO_DESIGN

- TODO_DESIGN_rear_arm_near_hidden_paint: rear near sleeve is fully covered by the cowl. It has a valid skinned node and no fabricated sleeve paint.
- TODO_DESIGN_rear_hand_near_hidden_paint: rear near glove has no own painted donor. Its rigid node is retained empty.
- TODO_DESIGN_chain_release_drop: protected release_at and angle_deg detach/tip the chain but give no drop translation or floor-contact timing. Existing floor-end release is retained; a floor drop is not claimed.

The earlier rear-leg donor warning was resolved by correcting ownership and retaining the certified trouser texels. It is not a remaining placeholder.

## Chosen defaults

`rr38_chosen_defaults.json` lists proof geometry, debug fixtures, timeouts, mutations, shard sizing and flat-region diagnostic thresholds. They do not author player-facing tuning. The 55.5-degree Pin gate limit is the protected 55-degree key rounded through the existing 1.5-degree presentation step, not a changed motion key. Registration/traces/stance bends are measurements; the 0.9 art scale and all action numbers come from existing data.

## Proof for the design owner

No windowed command was attempted. Run each stage from the task worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-38 && LABYRINTH_TASK_ID=rr-38 sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-38 && LABYRINTH_TASK_ID=rr-38 sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-38 && LABYRINTH_TASK_ID=rr-38 sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-38 && LABYRINTH_TASK_ID=rr-38 sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-38 && LABYRINTH_TASK_ID=rr-38 sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-38 && LABYRINTH_TASK_ID=rr-38 sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-38 && LABYRINTH_TASK_ID=rr-38 sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh review
```

All captures require 1920x1080 and 100% UI scale. Production also runs the rr-40 prepared sprite geometry regression with explicit Gaoler images in all four facings. Failed native gates still produce sheets/review media and preserve a nonzero status. Output roots are `rr38/proof/native_rest/`, `native/`, `contact_sheets/`, `idle_native/`, `production_native/`; the review movie is `rr38/proof/chainbound_gaoler_review.mp4`. No inspection_fixture command is requested by this brief; the design owner owns fixture preparation.

## Open issues

Native judgment and any director-painted underlays; the three design placeholders; native rest rebake/seal; the four untouched Godot program failures and optional Wisp benchmark failure above. Native-rest certification is the sole remaining failure in the post-fix Python integration rerun. Changes remain uncommitted for the design owner.

## Files changed

`rr38_CHANGED_FILES.txt` is the complete uncommitted inventory. It covers the Gaoler adapters/derived art and case, scoped density/identity/shadow/support records, production routing and trail/context adapters, deleted bespoke scripts, focused/regression/export/proof programs, two optional humanoid tools and the unstaged-deletion dependency-audit fix. Other figures' assets and protected inputs are unchanged (`rr38/proof/preservation.json`).
