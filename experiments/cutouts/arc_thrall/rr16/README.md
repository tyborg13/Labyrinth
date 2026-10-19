# rr-16 implementation handoff

All implementation changes are uncommitted on `codex/rr-16`. No commit, peer review, fixture preparation, publication or windowed run was performed. The brief assigns those stages to the design owner. The focused proof restriction in the unit brief takes precedence over the earlier general full-suite instruction: neither full Godot nor full Python suites were run.

## Numbered acceptance criteria

1. **Optional painted caps:** `action_direction.py` accepts samples without `parts`, but rejects missing skeletal evidence. The three previously failing rr14 checks pass. The new rr15 regression removes every painted part, then removes skeletal evidence and requires the named failure.
2. **Effective mode metadata:** mode-only supports emit their effective mode independently of roles or `view_keys`. Numeric tracks continue carrying their effective mode; legacy Seer bytes are retained. The new no-role fixture covers both `body` and `world_step`, and requires both views' complete compiled output to remain identical after an empty rear override (excluding the necessarily changed author-file digest). Recompiling the actual Thrall and Seer produces their existing compiled data exactly. No Thrall front jab/tether frame changes occurred: all 990 fresh pose rows match. No fresh pixel comparison was performed; paint, layouts, production renderer inputs and compiled bytes are unchanged. See `preservation.json`.
3. **Between-sample reach:** every key phase partitions the dense sampling. Suspect straight segments are measured in the first bone's animated frame and bisected to `1e-6` phase, pruning intervals that cannot improve the minimum. The review's 40/20 chain and .5001–.5009 crossing fails with a minimum approximately 0 px at .5005. Current Thrall paths pass; the unchanged overreach set is `front/jab/hand_far`, `front/death/tube_tip`, `front/death/hand_far`, `rear/death/hand_far`.
4. **Required direction coverage:** Thrall `cutout.json` declares `direction_clips: ["jab", "tether"]`. Every listed clip needs a positive check in each view, independently of the mutable channels. Fresh Godot evidence with all forward channels zero fails both views; zeroing only jab also fails despite positive tether checks. Seer is not enrolled in this new case-owned coverage requirement: its files remain untouched and its existing signed-direction diagnostics still pass.
5. **Exact pockets:** the existing approved jab 22 and death 31 reasons are unchanged. The reader matches bounding box plus pixel count and consumes each exception once. The native detector now retains those fields. Recorded from the retained native capture: jab `[282,248,283,250]` / 2 px; death `[280,252,282,256]` / 7 px (512px native proof canvas, exclusive right/bottom). `pocket_evidence.json` records source captures and hashes. Both were visually inspected. Counts `[2,50]`, `[7,50]`, wrong locations/counts, duplicate matches and approved-pocket-plus-extra-hole inputs fail. Seer's legacy exception data and rendering remain untouched.
6. **rr07 production:** Thrall uses `tests/rr11/production_capture.gd`, its rr11 case and humanoid three-pose idle contract. Other creatures retain their existing routing and assertions. All five rr07 production tests pass in the focused run.
7. **Sidecars:** headless import completed with exit 0 and produced all 114 reviewed missing files: 106 `.import`, eight `.uid`; inventory in `sidecars.txt`. No exclusions were added. The existing tracked-only repository test still fails because the sandbox prevents adding these files to Git. Checking that same guard against tracked files plus these 114 files passes. The guard and its assertions were not weakened.

The protected rr11 director file is unchanged (`1576888b210425a42ae17c33741f9bbe7870c577d1d36b7ba1fee6de0af38d15`). Seer's 777 protected files/binding-normalized records pass their existing identity test, and 1,258 fresh poses match exactly. No art, audio, fonts, game tuning, saves, analytics, runtime scripts or dependencies were changed.

## Files changed

- Gate implementation: `tools/humanoid_cutout/{action_direction,compiler,reach,native_exceptions,silhouette_gates,gates}.py`.
- Thrall case: `rr11/cutout.json`, `rr11/gate_exceptions.json`; refreshed headless `rr11/proof/{samples,directions,reach}.json`.
- Tests: `tests/test_rr07_production.py`, `tests/test_rr11_humanoid.py`, `tests/test_rr15_{action_direction,view_keys}.py`, new `tests/test_rr16_review_fixes.py`. Existing owned test runner IDs honor the task environment.
- Reproducible helpers: `../rr16_focused.py`, `../rr16_mutations.py`; this folder's evidence and handoff files.
- All 114 generated metadata files in `sidecars.txt`.

## Tests and probes run

Run from `/Users/borgerding/workspace/Labyrinth.worktrees/rr-16`. Logs are under `/private/tmp/labyrinth_codex/` unless otherwise stated.

```sh
python3 tools/godot_task_runner.py --task-id rr-16 --stream -- godot --headless --path . --import
python3 -B experiments/cutouts/arc_thrall/rr16_focused.py
python3 -B -m unittest tests.test_rr16_review_fixes
python3 -B experiments/cutouts/arc_thrall/rr16_mutations.py
python3 tools/godot_task_runner.py --task-id rr-16 --stream -- godot --headless --path . --script tests/rr11/action_direction.gd -- --case experiments/cutouts/arc_thrall/rr11 --output experiments/cutouts/arc_thrall/rr11/proof/samples.json
python3 -B experiments/cutouts/arc_thrall/rr11_gates.py
python3 tools/godot_task_runner.py --task-id rr-16 --stream -- godot --headless --path . --script tests/rr11/runtime_checks.gd
python3 tools/godot_task_runner.py --task-id rr-16 --stream -- godot --headless --path . --script tests/rr10/runtime_checks.gd
python3 tools/godot_task_runner.py --task-id rr-16 --stream -- godot --headless --path . --script tests/suites/sfx_sync_0_program.gd -- --assert-onsets
python3 tools/godot_task_runner.py --task-id rr-16 --stream -- godot --headless --path . --script tests/suites/sfx_sync_1_program.gd -- --assert-onsets
python3 tools/godot_task_runner.py --task-id rr-16 --stream -- godot --headless --path . --script tests/suites/sfx_sync_2_program.gd -- --assert-onsets
python3 -B tests/test_godot_sidecars.py
python3 -B tools/test_registration_audit.py
git diff --check
```

The focused helper runs only the brief's rr11, rr14, rr15, rr10, rr07 production, sidecar and registration tests, plus rr16 regressions. It redirects historical literal task IDs in nested runner calls to rr-16 without changing their assertions. Observed results:

```text
rr16-focused.log:
Ran 184 tests in 149.814s
FAILED (failures=1)
```

The sole failure is `test_tracked_sources_have_sidecars_and_sidecars_have_sources`, listing the 114 generated but untracked sidecars. The final new regression was added after this run and checked separately:

```text
rr16-regressions.log:
Ran 6 tests in 0.046s
OK

rr16-focused.log:
RR14 RUNTIME: PASS (246 checks; headless synthetic anatomy and foot IK)
RR14 SEER BYTE IDENTITY: PASS (777 files; only two input-binding objects excluded)
RR16 THRALL POSE IDENTITY: PASS (990 exact rows)
RR16 SEER POSE IDENTITY: PASS (1258 exact rows)

rr16-gates.log:
RR11 SOURCE/CUT GATES: PASS (0 errors; both views)
RR11 BONE/CUT/KNEE GATES: PASS (0 errors)
RR15 FRONT ACTION DIRECTION: PASS (458 positive checks)
RR15 FRONT REACH: PASS (11 keyed paths; 1000 intervals; 0 errors)
RR15 REAR ACTION DIRECTION: PASS (458 positive checks)
RR15 REAR REACH: PASS (11 keyed paths; 1000 intervals; 0 errors)

rr16-runtime.log:
RR11 RUNTIME: PASS (5722 checks; headless logic only)
rr16-seer-runtime.log:
RR10 RUNTIME: PASS (10 checks; headless logic only)

rr16-sfx_sync_0_program.log:
SFX SYNC HARNESS RESULT: PASS (4075 observations, 0 failures)
rr16-sfx_sync_1_program.log:
SFX SYNC HARNESS RESULT: PASS (3348 observations, 0 failures)
rr16-sfx_sync_2_program.log:
SFX SYNC HARNESS RESULT: PASS (1604 observations, 0 failures)

rr16-sidecars.log:
Ran 19 tests in 1.068s
FAILED (failures=1)

Additional working-tree inventory check:
RR16 SIDECAR WORKING TREE: PASS (106 .import; 8 .uid; 114 files ready for staging)

TEST REGISTRATION AUDIT: PASS (749 scripts; full suite=405, quarantined=29, windowed probe=315)
```

`git diff --check` exits 0. The pre-fix run (`rr16-before.log`) reproduced the three `parts` errors and obsolete rr07 Thrall failure. The new mode, short-dip and extra-hole regressions also failed against the original code before their fixes.

## Mutation table

| Removed guard | Regression result | Restored |
|---|---|---|
| 3: between-sample interval refinement | CAUGHT: assertion failure in narrow-dip regression | Byte for byte |
| 4: required clip coverage | CAUGHT: zero-forward and jab-only mutations incorrectly pass without guard | Byte for byte |
| 5: exact pocket matching (replaced by frame-wide suppression) | CAUGHT: extra-hole regression | Byte for byte |

See `mutations.json`, `rr16-mutations.log`, and `/private/tmp/labyrinth_codex/rr-16/mutations/fix{3,4,5}.log`. Each failure is an assertion failure; crashes and launch failures are not credited.

## TODO_DESIGN placeholders

None. No player-perceived decision was needed.

## Chosen defaults

Only synthetic regression fixtures: `MODE_FIXTURE_PELVIS_LIFT_PX=-1` (one-pixel support displacement); `POCKET_FIXTURE_SIZE_PX=16`, `POCKET_BODY_BOUNDS=(3,3,13,13)`, `POCKET_HOLE_BOUNDS=(7,7,9,9)`, `POCKET_EXPECTED_PIXELS=4`; `REACH_TOLERANCE_PX=.1`. These are named fields in `tests/test_rr16_review_fixes.py`. The 40/20 chain, crossing phases, 1e-6 resolution, and established 96px/2x sampler scale come from the brief or existing proof.

## Open issue: staging restriction

The staging attempt failed exactly:

```text
fatal: Unable to create '/Users/borgerding/workspace/Labyrinth/.git/worktrees/rr-16/index.lock': Operation not permitted
```

All files remain uncommitted and unstaged. No alternate Git metadata or bypass was used. In an authorized design-owner session, stage the exact inventory and rerun the repository guard:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-16 && python3 -c 'from pathlib import Path; import subprocess; subprocess.run(["git", "add", "--", *Path("experiments/cutouts/arc_thrall/rr16/sidecars.txt").read_text().splitlines()], check=True)'
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-16 && python3 -B tests/test_godot_sidecars.py
```

## Proof for the design owner

Fix 2 did not change actual compiled output, so it requires no visual-change inventory or recapture of the unchanged idle, density or production look. Native gate acceptance remains a director step: no window-server access is available here. To exercise the new pocket matcher against fresh bound native captures and produce the corresponding sheets/review, use the existing probes and 1920x1080/100% contracts:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-16 && LABYRINTH_TASK_ID=rr-16 sh experiments/cutouts/arc_thrall/rr11_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-16 && LABYRINTH_TASK_ID=rr-16 sh experiments/cutouts/arc_thrall/rr11_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-16 && LABYRINTH_TASK_ID=rr-16 sh experiments/cutouts/arc_thrall/rr11_proof.sh review
```

The native stage invokes `tools/visual_probe_runner.py --expect-size 1920x1080 --proof-contract tests/rr11/render_contract.json` and then the native gates. Outputs: `../rr11/proof/native/`, `../rr11/proof/contact_sheets/`, `../rr11/proof/arc_thrall_review.mp4` (relative to this handoff folder). No new captures were made or claimed here; the two inspected retained captures are identified in `pocket_evidence.json`. No inspection-fixture command was requested in the brief; preparation belongs to the design owner.
