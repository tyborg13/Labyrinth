# bug-01 — implementation and proof handoff

The owner-provided feedback-4 dump classifies 44 differing cases: one real
foreground-pillar redraw bug, five HP-ghost cases, and 38 obsolete-baseline or
fixture-input cases. The 62 other cases are equal controls. All 212 temporal
pairs are equal, rejecting shader TIME as the cause. See the complete
[case classification](bug_01_native_classification.md) and
[feedback-4 verification/native handoff](bug_01_feedback_4.md). Current review-fix
verification is in [bug_01_feedback_5.md](bug_01_feedback_5.md).

Production now redraws foreground candidates only when the draw path's complete
effective alpha changes, including unchanged actors and objects. No authored
opacity, timing, assets, mechanics, analytics, saves or input paths change.
Native comparisons retain strict pixel equality against independently fresh
production with equivalent complete inputs and settled HP transients. Original
pixels are asserted only for explicit unchanged submissions; structural reference
and cached-floor assertions stay. Changes are uncommitted
on `codex/bug-01`, based on owner-merged integration HEAD `aa3a6bf58`.

For feedback 5, the four focused programs and dump-enabled headless floor program pass, and the
unconditional-candidate-redraw mutation now fails the new negative assertions.
Full Godot recheck: `TEST RESULT: PASS`, 352.703 seconds; full Python:
`Ran 702 tests in 864.347s` / `OK (skipped=63)`. The first full Godot run had one
unmodified map-generation timing failure under concurrent Python load; both that
failure and the successful same-limits recheck are retained in the feedback-5 handoff.

## Root-cause table

| Test | Verdict | Player impact | Root-cause commit | Fix | Regression / proof |
| --- | --- | --- | --- | --- | --- |
| `prepared_other_character_view_test.gd` | Stale fixture | None demonstrated. Reversing the migrated empty reserve changes nothing. | `5b766ff7e` (deck-01; integrated by `3f8a19b15`). Timing-dependent boundary counting dates to `809d5b9ce`. | Reverse the active deck and assert that the input key really changes. Stop cancellation enumeration at an actually absent boundary, assert uninterrupted completion and fail on safety-limit exhaustion. Trigger owner termination when both future columns are attached and assert it occurred. | Existing input-capture/cancellation/ownership assertions; new source-mutation, scan-completion and complete-column termination preconditions. |
| `retained_character_inventory_equivalence_test.gd` | Stale time input | None demonstrated. Opening an unread tab legitimately commits elapsed run time; the two scenes sample different wall times. | `13ffa4a8a` (fix-02; integrated by `0d54a5970`). | Freeze the external clock before either scene is ready. Keep real sampling/commit/save logic and the entire dictionary comparison. | Existing `Presentation must not mutate authoritative state` and `Boundary open must preserve original authoritative state`. |
| `shop_retained_content_test.gd` | Stale paging fixture | None demonstrated. Its seven entries fit one nine-slot page; the page never advanced. | `b6d717756` changed page size from 2 to 9. This predates requested baseline `816f5e68a`. | Add spare gear locally until the fixture actually spans multiple pages. Shared flow data and production are unchanged. | Existing unchanged-page/control-identity assertions; new multi-page fixture precondition. |
| `static_floor_cache_equivalence_test.gd` | Bug plus stale references/fixtures | A new prop can remain obscured by an opaque pillar; removal can leave the pillar faded until an unrelated redraw. No stale lighting/navigation/room floor demonstrated. | `7d38b66ce` introduced prop-tile-only redraws, before requested baseline `816f5e68a`. Stale inputs also date to `5923db9da` and `6b4927d2f`. | Queue foreground candidates whose prop obstruction changes. Correct encounter closure, navigation setup and HP transients in proof; use strict fresh production pixels for changed presentations. | `Scene prop onset/removal must redraw its obstructing pillar` fails before fix and passes after. All 106 cases independently compare geometry, HUD, obstruction and floor inputs; native complete-pixel and one-pixel mutation proof pending owner run. |

The intended contracts already exist in production: deck-01 migrates reserve
spells into the active deck; fix-02 commits scene-owned time at save boundaries;
the shop clamps pages to available entries and retains unchanged pages; current
enemy adapters publish explicit derived collections. No new design choice was made.
The inventory diagnostic found only `run_stats.run_seconds` differing, for example
4.745594 versus 4.679938 seconds.

## Requirements

1. Reproduced all four unchanged programs. Before-change logs are
   `output/bug-01/{prepared,inventory,shop,floor}-before.log`.
   `history-bisection.log` records read-only binary searches through source history
   and adjacent feature-parent/feature predicates. No historical engine checkout
   was made or historical full suite claimed. The baseline-version shop test was
   also executed against current production and reproduced the failure.
2. The native dump demonstrated the case-21 pillar redraw defect. The minimal
   production fix and before/after regression are recorded in feedback 4.
3. Updated stale fixture/reference inputs without excluding pixels or fields.
   As requested in feedback 4, complete native pixels use fresh production for
   changed states and the frozen original only for unchanged submissions.
   Case/check counts vary with the existing 4 ms row-job slices; actual
   unfinished boundaries and actual owner invalidations are checked.
4. Execute the four standalone programs through qa-07's
   `tools/program_suite_runner.py --suite ...`. Do not register them in either
   program manifest: the owner will handle qa-08's supplemental manifest and
   quarantine. Current results are recorded below.

## Feedback 1: native proof and scheduler

The owner's run in `output/bug-01/director_native/` failed 38 complete-board
comparisons. Restored versus reference was exactly equal; restored versus fresh
differed by 4,940 pixels inside the hero's bounds. Disabling `_process()` alone
kept each persistent actor at its previous idle phase. These were proof failures,
not production floor defects.

`static_floor_proof_clock.gd` recursively disables processing, resets every
cutout renderer's `_idle_seconds` and reapplies its complete pose. This covers
the hero, enemies, illusions, and the maquette renderer through their shared
clock/pose interface. Board sprite clocks use the same fixed `_idle_elapsed`;
lighting flicker uses a fixed treatment clock. Explicit ambient, preview, umbra,
effect and torch-mote inputs remain fixed. Actors remain fully in the comparison;
no masks, tolerances or excluded pixels are used. Ordinary transitions still use
production selective redraw routing.

The headless regression first advances the actual and reference hero/enemy
clocks by different amounts, verifies the mismatch, freezes them, checks complete
applied-pose equality and checks clocks stay frozen across frames. The original
103 cases, including all 38 failing native cases, remain; three clock-regression
cases bring the total to 106.

Native proof also draws one magenta pixel inside the actual cached floor
viewport. Strict equality must reject both the cached floor and complete board
against untouched baselines, fresh and reference boards. Removing the pixel must
restore exact equality. `LABYRINTH_BUG_01_MUTATE_FLOOR=1` additionally sends that
corruption through the original cached-floor and complete-board assertions,
deliberately failing the program. The normal run includes the same negative
control without expecting the overall program to fail.

Deleted `program_sub_suite_batch.gd` and `tools/bug_01_programs.gd`. No scheduler
or registration replaces them; focused commands use qa-07's runner directly.

## Files changed

- `scripts/board_scene_prop_redraws.gd` and `scripts/combat_board_view.gd`:
  targeted invalidation of foreground candidates obstructing changed props.
- `tests/fixtures/static_floor_fresh_checks.gd`: independent geometry, HUD,
  obstruction, settled-ghost and complete floor-input regressions in every case.
- `tests/fixtures/static_floor_scene_prop_checks.gd`: unaffected-pillar and
  already-actor-obstructed-pillar onset/removal negatives, with real alpha checks.
- `tests/bug_01_feedback_5.md`: review aa3a6bf58 fixes and current verification.
- `tests/bug_01_native_classification.md`: all 106 owner-run case classifications.
- `tests/bug_01_feedback_4.md`: current commands, verification and open issues.
- `tests/prepared_other_character_view_test.gd`: real deck mutation, actual
  cancellation/termination boundaries, frozen clock.
- `tests/retained_character_inventory_equivalence_test.gd`: frozen external clock.
- `tests/shop_retained_content_test.gd`: genuine multi-page local fixture.
- `tests/static_floor_cache_equivalence_test.gd`: enforced UI scale and new
  restored/fresh/reference proof, clock regression, strict negative control.
- `tests/fixtures/static_floor_proof_clock.gd`: deterministic proof clocks and
  strict image comparator.
- `tests/fixtures/static_floor_diff_dump.gd`: opt-in diagnostic artifacts, strict
  RGBA statistics, masks and isolated mutation messages (feedback 2).
- `tests/fixtures/static_floor_diff_capture.gd`: independent fresh board and
  same-case native capture orchestration, compatible reference geometry and
  raw/pinned 0.25-second pairs (feedback 2/3).
- `tests/fixtures/static_floor_capture_io.gd`: native readback/fence/wait bridge.
- `tests/fixtures/static_floor_diff_capture_smoke.gd`: end-to-end capture smoke
  using the exact real board types and explicitly mocked native I/O.
- `tests/fixtures/static_floor_shader_time.gd`: proof-only shader copies with a
  controllable TIME uniform, immutable source shaders and per-material audits.
- `tests/fixtures/static_floor_diff_dump_checks.gd`: headless metrics, crop,
  mask, persistence and cleanup checks (feedback 2).
- `tests/bug_01_diff_dump.md`: current diagnostic command, results, defaults and
  interpretation contract; classification is deferred.
- `tests/fixtures/retention_play_clock.gd`: fixed external time input.
- `tests/fixtures/static_floor_cache_reference.gd`: current presentation adapters
  before the independent frozen renderer.
- `tests/helpers/program_sub_suite_batch.gd`: deleted per feedback 1.
- `tools/bug_01_programs.gd`: deleted per feedback 1.
- `tests/proof_contracts/bug_01_floor_restore.json`: mandatory four-image contract,
  including the floor mutation capture.
- `tests/bug_01_findings.md`: this handoff.
- `output/bug-01/`: local contract, investigation artifacts and observed logs.
  Its `.gdignore` is local-only per the output helper.

## Feedback 1 observed verification

All four programs passed through qa-07's runner, exit 0. Report:
`output/bug-01/qa-07-feedback-1.json` has `complete: true`, `failed: false`,
each `returncode: 0`, total `seconds: 92.779`. Exact child result lines:

```text
PREPARED OTHER CHARACTER VIEW RESULT: {"boundaries":{"equipment":16,"magic":31},"cancellation_boundaries":15,"cases":50,"checks":1195,"differences":0,"errors":[],"orphans":0}
CHARACTER RETENTION RESULT: {"cases":127,"differences":0,"errors":[],"orphan_nodes":0,"preparation_frames":5020}
SHOP RETAINED CONTENT TEST RESULT: PASS
RESTORED EMPTY BOARD LOGIC: PASS (native pixel proof requires window server)
STATIC FLOOR CACHE RESULT: {"cases":106,"checks":162325,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}
```

After naming the last debug fixture constants, the floor program passed again
through qa-07, exit 0, with the same result line. Final floor report:
`output/bug-01/qa-07-floor-feedback-1-final.json`, `complete: true`,
`failed: false`, `seconds: 7.189`. Direct focused headless floor execution
also returned 0 in `output/bug-01/floor-feedback-1.log`.

Prescribed sound-lab venv, exit 0: `Ran 39 tests in 35.242s` / `OK`.
Log: `output/bug-01/python-sfx-feedback-1.log`.

Integrated full Godot suite, exit 0: all 33 registered child programs passed.
Log: `output/bug-01/godot-full-feedback-1.log`. Exact result lines:

```text
MAIN BODY RUNTIME: 331.158 seconds
MAIN BODY ASSERTIONS: 378785
FULL SUITE RUNTIME: 371.073 seconds (budget 900 seconds)
TEST RESULT: PASS
```

The full suite still prints its existing ObjectDB leak warnings. The focused
bug-01 equivalence programs report zero orphan nodes. No existing assertions
or failure expectations were changed.

Full Python discovery, exit 0, log `output/bug-01/python-feedback-1.log`:

```text
Ran 698 tests in 712.423s
OK (skipped=63)
```

The 63 skips are the same optional-environment categories: 6 pinned classical
audio checks, 16 arrangement checks, 2 opt-in Blender checks and 39 sound-lab
checks. The 39 sound-lab checks passed separately as reported above; no
dependencies were installed. Output import hygiene reported
`OUTPUT GDIGNORE: PASS (14 folders; 3 referenced roots)`. `git diff --check`
passed after the final edits. No revised native proof was run here.

Current commands (all from this task worktree):

```sh
python3 tools/output_gdignore.py
python3 tools/program_suite_runner.py --task-id bug-01 --result-file output/bug-01/qa-07-feedback-1.json --suite prepared_other_character_view_test --suite retained_character_inventory_equivalence_test --suite shop_retained_content_test --suite static_floor_cache_equivalence_test
python3 tools/program_suite_runner.py --task-id bug-01 --result-file output/bug-01/qa-07-floor-feedback-1-final.json --suite static_floor_cache_equivalence_test
python3 tools/godot_task_runner.py --task-id bug-01 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
/Users/borgerding/.cache/umbra-sfx/venv/bin/python -m unittest discover -s tests -p 'test_sfx_lab.py' -v
```

## Observed verification before feedback 1

Focused direct programs and the focused batch all returned exit 0. Current unit
result lines from the final full run (`output/bug-01/godot-full-final.log`):

```text
TEST RESULT: PASS
PREPARED OTHER CHARACTER VIEW RESULT: {"boundaries":{"equipment":14,"magic":28},"cancellation_boundaries":13,"cases":46,"checks":1045,"differences":0,"errors":[],"orphans":0}
PROGRAM SUITE prepared_other_character_view_test: PASS
CHARACTER RETENTION RESULT: {"cases":113,"differences":0,"errors":[],"orphan_nodes":0,"preparation_frames":3437}
PROGRAM SUITE retained_character_inventory_equivalence_test: PASS
SHOP RETAINED CONTENT TEST RESULT: PASS
PROGRAM SUITE shop_retained_content_test: PASS
STATIC FLOOR CACHE RESULT: {"cases":103,"checks":158583,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}
PROGRAM SUITE static_floor_cache_equivalence_test: PASS
FULL SUITE RUNTIME: 718.780 seconds (budget 900 seconds)
TEST RESULT: PASS
```

Other observed results:

| Check | Exact result lines | Log under `output/bug-01/` |
| --- | --- | --- |
| Full Python discovery, exit 0 | `Ran 670 tests in 612.842s` / `OK (skipped=63)` | `python-full.log` |
| Prescribed SFX venv, exit 0 | `Ran 39 tests in 26.268s` / `OK` | `python-sfx.log` |
| UI identity lint tests, exit 0 | `Ran 25 tests in 3.553s` / `OK` | `ui-identity.log` |
| Task-runner regression tests, exit 0 | `Ran 11 tests in 5.061s` / `OK` | `python-runner-final.log` |
| Registry parser check, exit 0 | No parse/script errors; `--check-only` | `program-registry-parse.log` |
| Output import hygiene | `OUTPUT GDIGNORE: PASS (13 folders; 3 referenced roots)` | `output-gdignore.log` |

Python skips comprise 6 pinned classical-audio environment tests, 16 arrangement
tests without mido/music21, 2 opt-in native Blender tests, and 39 sound-lab tests
without optional modules. The 39 sound-lab tests passed separately in their
installed prescribed venv. No dependencies were installed.

Two serial full-suite attempts hit the unchanged 900-second outer limit before
reaching bug-01 (exit 124; `error: command timed out after 900 seconds.`), retained
in `godot-full.log` and `godot-full-serial.log`. Bounded independent execution
lets the final full registry complete within that same limit. Full output contains
ObjectDB leak warnings; the three instrumented equivalence programs explicitly report zero orphan nodes.

Commands executed from the task worktree:

```sh
python3 tools/output_gdignore.py
python3 tools/godot_task_runner.py --task-id bug-01 --stream -- godot --headless --path . --script tests/prepared_other_character_view_test.gd
python3 tools/godot_task_runner.py --task-id bug-01 --stream -- godot --headless --path . --script tests/retained_character_inventory_equivalence_test.gd
python3 tools/godot_task_runner.py --task-id bug-01 --stream -- godot --headless --path . --script tests/shop_retained_content_test.gd
python3 tools/godot_task_runner.py --task-id bug-01 --stream -- godot --headless --path . --script tests/static_floor_cache_equivalence_test.gd
python3 tools/godot_task_runner.py --task-id bug-01 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
/Users/borgerding/.cache/umbra-sfx/venv/bin/python -m unittest discover -s tests -p 'test_sfx_lab.py' -v
python3 tests/test_ui_identity_lint.py
python3 -m unittest discover -s tests -p 'test_godot_task_runner.py' -v
python3 tools/godot_task_runner.py --task-id bug-01 --stream -- godot --headless --path . --check-only --script tests/helpers/program_sub_suites.gd
```

## Proof for the design owner

The native diagnostic execution cap is the runner's real `--timeout 600` CLI
argument in the current proof and mutation commands. It is not enforced by a
GDScript constant; the unused `NATIVE_DUMP_TIMEOUT_SECONDS` was removed in
feedback 5. The native commands and strict pixel contract remain unchanged.

The next requested runs are the feedback-4 proof and mutation commands in
[bug_01_feedback_4.md](bug_01_feedback_4.md). The two feedback-1 commands below
were run by the owner and failed; they are not evidence of a native pass.

Revised native proof is pending: this sandbox has no window-server access. No
windowed run was attempted here. Run the positive proof once:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/bug-01 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --attempts 1 tests/static_floor_cache_equivalence_test.gd --task-id bug-01 --expect-size 1920x1080 --proof-contract tests/proof_contracts/bug_01_floor_restore.json --result-manifest output/bug-01/floor-native-feedback-1.manifest.json
```

Then run the intentional failure once (expected nonzero exit, cached-floor
assertion failure, and `deliberate floor-pixel mutation` in `pixel_differences`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/bug-01 && LABYRINTH_BUG_01_MUTATE_FLOOR=1 python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --attempts 1 tests/static_floor_cache_equivalence_test.gd --task-id bug-01 --expect-size 1920x1080 --proof-contract tests/proof_contracts/bug_01_floor_restore.json --result-manifest output/bug-01/floor-mutation-feedback-1.manifest.json
```

Expected capture paths, not yet generated:

- `user://bug_01_floor_restored.png`
- `user://bug_01_floor_fresh.png`
- `user://bug_01_floor_reference.png`
- `user://bug_01_floor_mutated.png`

The program enforces 1920x1080 and UI scale 1.0, prints absolute paths, and asserts
byte-for-byte equality of restored/fresh/reference images. It requires the
mutated image to differ and requires exact equality after removing the mutation.
The positive manifest records validated image paths. Expected positive lines:
`FLOOR PIXEL NEGATIVE CONTROL: PASS (strict equality rejects mutation)`,
`RESTORED EMPTY BOARD NATIVE: PASS (1920x1080 ui_scale=1.0)`, and
`STATIC FLOOR CACHE RESULT` with `native:true`, `cases:106`, empty `errors` and
empty `pixel_differences`. These native results have not been observed here.
Inspect the native captures before concluding visual equivalence.
No playable inspection fixture is needed for this test-only change; the required
manual inspection is the native restored/fresh/reference comparison and floor
mutation check. The owner handles Git, review, inspection and publication.

## TODO_DESIGN placeholders

None.

## Chosen defaults

Only test/proof/execution inputs were chosen:

- `RETENTION_CLOCK_USEC = 1000000`: identical fixed clock input in both scenes.
- `MAX_CANCELLATION_BOUNDARIES = 64`: safety limit with a completion assertion.
- `PROOF_AMBIENT_SECONDS = 12.0`, `PROOF_IDLE_SECONDS = 2.0`: existing frozen
  samples reused for the fresh comparison board.
- `ProofClock.ACTOR_SECONDS = 0.0`: fixed idle sample for every cutout actor.
- `CLOCK_DRIFT_ACTUAL_SECONDS = 0.19`, `CLOCK_DRIFT_REFERENCE_SECONDS = 0.57`:
  deliberately different histories in the clock regression.
- `CLOCK_FIXTURE_ENEMY`: existing warden, id 1, tile (6,4), HP 24/24.
- `FLOOR_MUTATION_TILE = (4,4)`, `FLOOR_MUTATION_COLOR = Color.MAGENTA`:
  one-pixel native corruption on an unobstructed floor tile.
- `COMPARATOR_FIXTURE_SIZE = (2,2)`, `COMPARATOR_MUTATION_PIXEL = (1,1)`:
  headless one-pixel comparator check.
- `RESTORE_PROOF_SETTLE_FRAMES = 3`: settle the fresh nested native viewport.
- `PAGING_FIXTURE_SPARE_GEAR_ID = "iron_cleaver"`: local spare entries until
  inventory exceeds the production page size.
- `PROOF_ENCOUNTER_TYPES = ["warden"]`: the test's future actor family is included
  in the fixed room envelope from entry; no production encounter value changes.
- Contract `min_luma_range = 8`, `min_luma_stdev = 2`: reject blank proof images.
- `PROOF_SIZE = 1920x1080`, `PROOF_UI_SCALE = 1.0`: mandated proof settings.

## Open issues / scope limits

- Native captures still require the owner's windowed run and inspection.
- The full suite prints ObjectDB leak warnings despite passing; the three instrumented equivalence
  programs report zero orphan nodes.
- Task contracts are in `output/bug-01/contract.md` and
  `output/bug-01/feedback-{1,2,3,4,5}-contract.md`; owner-managed metadata is untouched.

No commit, push, merge, rebase, stash, branch switch, peer review, signoff, queue
edit, or `tests/quarantine.json` edit was performed.
